"""Extract an iso-potential surface from the Laplacian field.

Level 1 sits just under the WM/GM boundary; level 8 sits deep, close to the
ventricle. The iso-values are not evenly spaced because the potential field is
not linear in depth -- they were chosen so the resulting surfaces are roughly
evenly spaced in the white matter.

Original: marching_cube.py
"""

from __future__ import annotations

import argparse

import mne
import nibabel as nib
from skimage import measure

from wmba.paths import add_common_args, resolve

# Iso-value per level. Indices 0 and 9 are kept for reference but are NOT
# supported: level 0 sits essentially on the WM surface, where marching cubes is
# often degenerate, and level 9 runs into the ventricle. The published template
# covers 1..8 only.
LAP_VAL = [9998.5, 9995, 9970, 9880, 9500, 8700, 7300, 6000, 5000, 3000]

MIN_LEVEL, MAX_LEVEL = 1, 8


def extract(scan_dir, hemi: str, level: int) -> str:
    if not MIN_LEVEL <= level <= MAX_LEVEL:
        raise SystemExit(
            f"level must be in {MIN_LEVEL}..{MAX_LEVEL}, got {level}. "
            "Levels 0 and 9 have iso-values defined in LAP_VAL but are not "
            "supported: 0 is degenerate on the WM surface and 9 reaches the "
            "ventricle."
        )

    lap_path = scan_dir / "mask" / f"lap_{hemi}.nii"
    if not lap_path.is_file():
        raise SystemExit(f"missing input: {lap_path} (run wmba.laplacian first)")

    lap = nib.load(str(lap_path)).get_fdata()

    verts, faces, _normals, _values = measure.marching_cubes(
        lap, LAP_VAL[level], allow_degenerate=True
    )

    out_dir = scan_dir / "surf"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{hemi}.lvl{level}"

    mne.write_surface(
        str(out_path), verts, faces, file_format="freesurfer", overwrite=True
    )
    return str(out_path)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extract one iso-potential white-matter surface."
    )
    add_common_args(parser)
    parser.add_argument(
        "--level", type=int, required=True, choices=range(MIN_LEVEL, MAX_LEVEL + 1),
        metavar=f"{{{MIN_LEVEL}..{MAX_LEVEL}}}",
        help=f"iso-level, {MIN_LEVEL} (superficial) to {MAX_LEVEL} (deep)",
    )
    args = parser.parse_args()

    scan_dir = resolve(args)
    print(extract(scan_dir, args.hemi, args.level))


if __name__ == "__main__":
    main()
