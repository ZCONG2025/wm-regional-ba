"""Sample FLAIR intensity at every vertex of an icosphere-resampled mid-surface.

Input is the icosphere-resampled surface written by stage 06, a FreeSurfer binary
surface named `<hemi>_lvl<level>_ico_<order>`. Output is one intensity per vertex,
in the icosphere vertex order, so values are directly comparable across subjects.

Datasets produced before stage 06 was rewritten hold `<hemi>_coord.mat` instead,
written from an `.obj` by a MATLAB step that no longer exists. Those are still
read, so old and new runs stay comparable.

Intensities are divided by the volume maximum, which makes them comparable across
scanners only to the extent that the FLAIR intensity range is comparable. If you
need a stronger harmonisation, do it before this stage.

Original: sampling.py
"""

from __future__ import annotations

import argparse

import os

import mne
import nibabel as nib
import numpy as np
import scipy.io
import torch

from wmba.mesh_utils import aggregate_from_indices, normalize_vertices_flip
from wmba.paths import add_common_args, resolve

# aseg labels excluded from the surface feature: thalamus, caudate, putamen,
# pallidum, accumbens, lateral ventricle, choroid plexus, hippocampus (L/R).
BGIT_REGIONS = [10, 49, 13, 52, 12, 51, 11, 50, 26, 58, 4, 43, 31, 63, 17, 53]


def _sample(volume: torch.Tensor, vertices: torch.Tensor, shape, mode: str):
    """Sample one volume at vertex locations. `volume` is (1, 1, *shape)."""
    n_verts = vertices.shape[0]
    grid = normalize_vertices_flip(vertices, shape).view(1, n_verts, 3)
    return aggregate_from_indices((volume,), grid, range(1), mode=mode).view(n_verts)


def load_vertices(mid_dir, hemi: str, level: int, order: str | int | None = None) -> np.ndarray:
    """Vertex coordinates of the icosphere-resampled mid-surface, as (N, 3).

    Prefers the FreeSurfer surface written by stage 06; falls back to the
    `<hemi>_coord.mat` produced by the retired MATLAB step.
    """
    if order is None:
        order = os.environ.get("WMBA_ICO_ORDER", "6")

    surf_path = mid_dir / f"{hemi}_lvl{level}_ico_{order}"
    if surf_path.is_file():
        verts, _faces = mne.read_surface(str(surf_path))
        return np.asarray(verts, dtype=np.float64)

    legacy = mid_dir / f"{hemi}_coord.mat"
    if legacy.is_file():
        return np.asarray(scipy.io.loadmat(str(legacy))["coord"], dtype=np.float64)

    raise SystemExit(
        f"no resampled surface for {hemi} lvl{level}: expected {surf_path} "
        f"(or the legacy {legacy}). Run bin/06_surfreg_pass2.sh first."
    )


def sample(scan_dir, hemi: str, level: int, flair_id: str, bgit_mask: str = "legacy") -> str:
    flair_path = scan_dir / f"{flair_id}_FLAIR_converted.nii.gz"
    aseg_path = scan_dir / "aseg.mgz"
    for p in (flair_path, aseg_path):
        if not p.is_file():
            raise SystemExit(f"missing input: {p}")
    mid_dir = scan_dir / "midsurf" / f"lvl{level}"

    flair_img = nib.load(str(flair_path))
    flair = flair_img.get_fdata()
    shape = tuple(int(s) for s in flair.shape)

    aseg_img = nib.load(str(aseg_path))
    aseg = aseg_img.get_fdata()
    if tuple(int(s) for s in aseg.shape) != shape:
        raise SystemExit(
            f"FLAIR {shape} and aseg {aseg.shape} are not on the same grid; "
            "the FLAIR must be resampled to the conformed T1 (stage 07)."
        )

    verts = torch.FloatTensor(load_vertices(mid_dir, hemi, level)).view(-1, 3)

    flair_t = torch.FloatTensor(flair).view(1, 1, *shape)
    flair_t = flair_t / torch.max(flair_t)
    features = _sample(flair_t, verts, shape, mode="trilinear").numpy()

    if bgit_mask == "fixed":
        aseg_t = torch.FloatTensor(aseg).view(1, 1, *shape)
        labels = _sample(aseg_t, verts, shape, mode="nearest").numpy()
        excluded = np.isin(np.rint(labels).astype(np.int64), BGIT_REGIONS)
        features[excluded] = 0
        print(f"BGIT mask: zeroed {int(excluded.sum())} / {len(features)} vertices")
    else:
        # The original code's exclusion step silently did nothing; see
        # docs/known_issues.md. Kept as the default so results reproduce.
        print("BGIT mask: disabled (legacy behaviour), no vertices excluded")

    out_path = mid_dir / f"{flair_id}_{hemi}.txt"
    np.savetxt(str(out_path), features)
    return str(out_path)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sample FLAIR intensity on an icosphere-resampled mid-surface."
    )
    add_common_args(parser)
    parser.add_argument("--level", type=int, required=True)
    parser.add_argument("--flair", required=True, help="FLAIR image identifier")
    parser.add_argument(
        "--bgit-mask",
        choices=["legacy", "fixed"],
        default="legacy",
        help=(
            "'legacy' (default) reproduces the published behaviour, in which no "
            "vertices are excluded. 'fixed' actually zeroes vertices falling in "
            "subcortical structures. See docs/known_issues.md."
        ),
    )
    args = parser.parse_args()

    scan_dir = resolve(args)
    print(sample(scan_dir, args.hemi, args.level, args.flair, args.bgit_mask))


if __name__ == "__main__":
    main()
