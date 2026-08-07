"""Mesh <-> voxel coordinate helpers.

Copyright (c) 2024-2026 Cong Zang
Portions copyright (c) Fabi Bongratz and contributors, from Vox2Cortex
(https://github.com/ai-med/Vox2Cortex), used and modified under the GPL-3.0.

This file is part of WM-RegionalBA and is licensed under the GNU General Public
License v3.0. See the LICENSE file at the repository root. The specific
functions adapted from Vox2Cortex, and how they were modified, are listed in
NOTICE.

SPDX-License-Identifier: GPL-3.0-only

Coordinate conventions
----------------------
`normalize_vertices_per_max_dim` maps voxel indices to [-1, 1] using the *largest*
image dimension for all three axes, which keeps the mesh isotropic. Its inverse is
`unnormalize_vertices_per_max_dim`.

`normalize_vertices_flip` additionally reverses the axis order, which is what
`torch.nn.functional.grid_sample` expects (it indexes as x=last axis).
"""

from __future__ import annotations

from typing import Tuple, Union

import numpy as np
import torch
import torch.nn.functional as F
import trimesh

ArrayLike = Union[torch.Tensor, np.ndarray]


def _check_packed(vertices: ArrayLike, shape: Tuple[int, ...]) -> None:
    assert len(vertices.shape) == 2, "Vertices should be packed."
    assert (
        len(shape) == 3 and vertices.shape[1] == 3
        or len(shape) == 2 and vertices.shape[1] == 2
    ), "Coordinates should be 2 or 3 dim."


def normalize_vertices_per_max_dim(
    vertices: ArrayLike,
    shape: Tuple[int, int, int],
    return_affine: bool = False,
):
    """Normalise voxel coordinates to [-1, 1] w.r.t. the maximum image dimension.

    If `return_affine`, also return the matrix m with v_new = (m @ v.T).T.
    """
    _check_packed(vertices, shape)

    v_new = 2 * (vertices / (np.max(shape) - 1) - 0.5)
    if not return_affine:
        return v_new

    mult = 2.0 / (np.max(shape) - 1)
    add = -1
    return v_new, np.array(
        [
            [mult, 0, 0, add],
            [0, mult, 0, add],
            [0, 0, mult, add],
            [0, 0, 0, 1],
        ]
    )


def unnormalize_vertices_per_max_dim(vertices: ArrayLike, shape: Tuple[int, int, int]):
    """Inverse of `normalize_vertices_per_max_dim`."""
    _check_packed(vertices, shape)
    return (0.5 * vertices + 0.5) * (np.max(shape) - 1)


def normalize_vertices_flip(
    vertices: ArrayLike,
    shape: Tuple[int, int, int],
    faces: ArrayLike | None = None,
):
    """Normalise to [-1, 1] per axis and flip axis order for `grid_sample`."""
    _check_packed(vertices, shape)

    if isinstance(vertices, torch.Tensor):
        shape_t = (
            torch.tensor(shape).float().to(vertices.device).flip(dims=[0]).unsqueeze(0)
        )
        vertices = vertices.flip(dims=[1])
    elif isinstance(vertices, np.ndarray):
        shape_t = np.flip(np.array(shape, dtype=float), axis=0)[None]
        vertices = np.flip(vertices, axis=1)
    else:
        raise TypeError(type(vertices))

    new_verts = 2 * (vertices / (shape_t - 1) - 0.5)

    if faces is None:
        return new_verts

    assert len(faces.shape) == 2, "Faces should be packed."
    assert faces.shape[1] == 3, "Faces should be 3D."
    if isinstance(faces, torch.Tensor):
        new_faces = faces.flip(dims=[1])
    elif isinstance(faces, np.ndarray):
        new_faces = np.flip(faces, axis=1)
    else:
        raise TypeError(type(faces))

    return new_verts, new_faces


def get_occupied_voxels_trimesh(vertices, faces, shape) -> torch.Tensor:
    """Voxel indices enclosed by a closed triangular mesh."""
    mesh = trimesh.Trimesh(
        vertices=vertices.cpu().numpy(), faces=faces.cpu().numpy()
    )

    volume = mesh.voxelized(pitch=1.0)
    volume.fill()  # fill interior voxels in place

    occupancy = volume.matrix.astype(bool)
    occupied = np.array(np.nonzero(occupancy)).T

    # Shift back from the voxel grid's local frame into image indices.
    offset = volume.points.min(axis=0) if hasattr(volume, "points") else np.zeros(3)
    occupied = occupied + offset.astype(int)

    inside = np.all((occupied >= 0) & (occupied < np.array(shape)), axis=1)
    return torch.tensor(occupied[inside], dtype=torch.long)


def voxelize_mesh_trimesh(vertices, faces, shape, n_m_classes: int = 1) -> torch.Tensor:
    """Rasterise a mesh into a label volume of `shape`, one channel per class.

    Occupied voxels are labelled 2, everything else 0. `masking.py` then relabels
    those into the Laplace boundary conditions.
    """
    assert len(shape) == 3, "Shape should be 3D"
    assert (
        n_m_classes == vertices.shape[0] == faces.shape[0]
        or (n_m_classes == 1 and vertices.ndim == faces.ndim == 2)
    ), "Wrong shape of vertices and/or faces."

    voxelized_mesh = torch.zeros(shape, dtype=torch.long)
    vertices = vertices.view(n_m_classes, -1, 3)
    faces = faces.view(n_m_classes, -1, 3)
    unnorm_verts = unnormalize_vertices_per_max_dim(
        vertices.view(-1, 3), shape
    ).view(n_m_classes, -1, 3)

    voxelized_all = []
    for v, f in zip(unnorm_verts, faces):
        vm = voxelized_mesh.clone()
        pv = get_occupied_voxels_trimesh(v, f, shape)
        if pv is not None and len(pv) > 0:
            vm[pv[:, 0], pv[:, 1], pv[:, 2]] = 2
        voxelized_all.append(vm)

    return torch.stack(voxelized_all)


def aggregate_trilinear(voxel_features, vertices, mode: str = "bilinear"):
    """Sample a volume at vertex locations.

    `mode` is passed straight to `grid_sample`: use "bilinear" for continuous
    images and "nearest" for label maps.
    """
    if vertices.shape[-1] != 3:
        raise ValueError("Wrong dimensionality of vertices.")
    vertices_ = vertices[:, :, None, None]

    features = F.grid_sample(
        voxel_features,
        vertices_,
        mode=mode,
        padding_mode="border",
        align_corners=True,
    )
    # Channel dimension <--> V dimension
    return features[:, :, :, 0, 0].transpose(2, 1)


def aggregate_from_indices(voxel_features, vertices, skip_indices, mode="bilinear"):
    """Sample several volumes at the same vertex locations and concatenate.

    Note: `grid_sample` has no separate 3-D name, so "trilinear" is an alias for
    "bilinear" here -- it is trilinear because the input is 5-D.
    """
    if mode == "trilinear":
        mode = "bilinear"
    if mode not in ("bilinear", "nearest"):
        raise ValueError(f"unsupported sampling mode: {mode}")

    features = [
        aggregate_trilinear(voxel_features[i], vertices, mode) for i in skip_indices
    ]
    if not features:
        raise ValueError("no volumes selected by skip_indices")

    return torch.cat(features, dim=2)
