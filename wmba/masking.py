"""Build the domain for the Laplace equation inside one hemisphere's white matter.

The domain is bounded by two surfaces:

    label 3 -- outside the WM surface  (Dirichlet, high potential)
    label 2 -- inside the WM           (the domain to solve in)
    label 1 -- the lateral ventricle   (Dirichlet, zero potential)

The outer boundary comes from rasterising FreeSurfer's `?h.white` surface; the
inner boundary comes from the aseg lateral-ventricle label (4 = left, 43 = right).

Original: masking.py -- Cong Zang, 2024-02-01
"""

from __future__ import annotations

import argparse

import mne
import nibabel as nib
import numpy as np
import torch
from mne.transforms import apply_trans

from wmba.mesh_utils import normalize_vertices_per_max_dim, voxelize_mesh_trimesh
from wmba.paths import add_common_args, resolve

# aseg.mgz labels for the lateral ventricles
VENTRICLE_LABEL = {"lh": 4, "rh": 43}

OUTSIDE, INSIDE, VENTRICLE = 3, 2, 1


def make_mask(scan_dir, hemi: str) -> str:
    aseg_path = scan_dir / "aseg.mgz"
    white_path = scan_dir / f"{hemi}.white"
    for p in (aseg_path, white_path):
        if not p.is_file():
            raise SystemExit(f"missing input: {p}")

    img_fs = nib.load(str(aseg_path))
    seg = img_fs.get_fdata()
    shape = tuple(int(s) for s in seg.shape)

    # FreeSurfer surfaces live in "tkreg" surface RAS (mm); move them to voxel
    # indices so they can be rasterised onto the aseg grid.
    T = img_fs.header.get_vox2ras_tkr()
    verts, faces = mne.read_surface(str(white_path))
    faces = faces.astype(np.float32)
    verts_vox = apply_trans(np.linalg.inv(T), verts)

    normalized = normalize_vertices_per_max_dim(
        torch.FloatTensor(verts_vox).view(-1, 3), shape, return_affine=False
    )
    occupancy = voxelize_mesh_trimesh(
        normalized, torch.FloatTensor(faces), shape, 1
    ).squeeze(0)

    mask = occupancy.detach().numpy()
    mask[mask == 0] = OUTSIDE
    mask[mask == 2] = INSIDE
    mask[seg == VENTRICLE_LABEL[hemi]] = VENTRICLE

    out_dir = scan_dir / "mask"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"lap_mask_{hemi}.nii"

    nib.save(
        nib.Nifti1Image(
            mask.reshape(shape).astype(np.int32), img_fs.affine, img_fs.header
        ),
        str(out_path),
    )
    return str(out_path)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build the Laplacian domain mask for one hemisphere."
    )
    add_common_args(parser)
    args = parser.parse_args()

    scan_dir = resolve(args)
    print(make_mask(scan_dir, args.hemi))


if __name__ == "__main__":
    main()
