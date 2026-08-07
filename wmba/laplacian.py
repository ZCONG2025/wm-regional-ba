"""Solve the Laplace equation in the white matter by Jacobi iteration.

Given the mask from `masking.py`, the potential is pinned to `V_OUTER` on the
WM surface and 0 in the ventricle, then relaxed inside the WM until successive
iterates stop changing. Iso-levels of the resulting field are the "mid-surfaces"
that `marching_cube.py` extracts: they interpolate smoothly between the
ventricle and the WM/GM boundary.

Inspired by
https://github.com/lukepolson/youtube_channel/blob/main/Python%20Metaphysics%20Series/vid31.ipynb

Original: laplacian.py -- Cong Zang, 2024-02-01
"""

from __future__ import annotations

import argparse

import nibabel as nib
import numpy as np
from scipy.ndimage import convolve, generate_binary_structure

from wmba.masking import INSIDE, OUTSIDE, VENTRICLE
from wmba.paths import add_common_args, resolve

V_OUTER = 10000  # potential on the WM surface
V_INIT = 5000  # initial guess inside the WM

DEFAULT_MAX_ITERS = 10000
DEFAULT_TOL = 5e-7


def solve(
    scan_dir,
    hemi: str,
    max_iters: int = DEFAULT_MAX_ITERS,
    tol: float = DEFAULT_TOL,
    verbose: bool = False,
) -> str:
    mask_path = scan_dir / "mask" / f"lap_mask_{hemi}.nii"
    if not mask_path.is_file():
        raise SystemExit(f"missing input: {mask_path} (run wmba.masking first)")

    seg_img = nib.load(str(mask_path))
    seg = np.asarray(seg_img.get_fdata())
    grid = np.asarray(seg_img.get_fdata())
    shape = seg.shape

    # 6-neighbour averaging kernel: the discrete Laplacian update.
    kern = generate_binary_structure(3, 1).astype(float) / 6
    kern[1, 1, 1] = 0

    mask_out = seg == OUTSIDE
    mask_in = seg == VENTRICLE
    mask_lap = seg == INSIDE

    grid[mask_out] = V_OUTER
    grid[mask_in] = 0
    grid[mask_lap] = V_INIT

    n_domain = np.sum(mask_lap)
    if n_domain == 0:
        raise SystemExit(f"empty Laplacian domain in {mask_path}")

    iters = 0
    err = np.inf
    while iters <= max_iters and err >= tol:
        grid_updated = convolve(grid, kern, mode="constant")
        # Dirichlet boundary conditions, re-imposed after every sweep.
        grid_updated[mask_out] = V_OUTER
        grid_updated[mask_in] = 0

        err = np.sum((grid - grid_updated) ** 2) / n_domain
        grid = grid_updated
        iters += 1
        if verbose or iters % 500 == 0:
            print(f"  iter {iters:5d}  err {err:.3e}", flush=True)

    print(f"converged after {iters} iterations (err {err:.3e})")

    out_path = scan_dir / "mask" / f"lap_{hemi}.nii"
    nib.save(
        nib.Nifti1Image(
            grid.reshape(shape).astype(np.int32), seg_img.affine, seg_img.header
        ),
        str(out_path),
    )
    return str(out_path)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Solve the Laplace equation inside the white matter."
    )
    add_common_args(parser)
    parser.add_argument("--max-iters", type=int, default=DEFAULT_MAX_ITERS)
    parser.add_argument("--tol", type=float, default=DEFAULT_TOL)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    scan_dir = resolve(args)
    print(solve(scan_dir, args.hemi, args.max_iters, args.tol, args.verbose))


if __name__ == "__main__":
    main()
