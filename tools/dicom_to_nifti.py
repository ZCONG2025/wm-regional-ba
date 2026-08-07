#!/usr/bin/env python3
"""Convert a DICOM series directory to a single NIfTI file.

    python tools/dicom_to_nifti.py <dicom_dir> <output.nii.gz>
    python tools/dicom_to_nifti.py <dicom_dir> <outdir> --all-series

Only needed if your source images are DICOM. If you already have NIfTI, put the
T1 and FLAIR where config/config.sh points and skip this.

Original: DICOM2NIFTI.py (paths were placeholders) and for_python.ksh (which
called spec2nii on a site-specific directory tree).
"""

from __future__ import annotations

import argparse
from pathlib import Path

import SimpleITK as sitk


def convert_series(dicom_dir: Path, series_id: str, out_path: Path) -> None:
    reader = sitk.ImageSeriesReader()
    files = reader.GetGDCMSeriesFileNames(str(dicom_dir), series_id)
    reader.SetFileNames(files)
    image = reader.Execute()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sitk.WriteImage(image, str(out_path))
    print(f"{series_id}: {len(files)} slices -> {out_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("dicom_dir", type=Path)
    parser.add_argument("output", type=Path,
                        help="output file, or output directory with --all-series")
    parser.add_argument("--all-series", action="store_true",
                        help="convert every series found, named <series_uid>.nii.gz")
    args = parser.parse_args()

    if not args.dicom_dir.is_dir():
        raise SystemExit(f"not a directory: {args.dicom_dir}")

    reader = sitk.ImageSeriesReader()
    series_ids = reader.GetGDCMSeriesIDs(str(args.dicom_dir))
    if not series_ids:
        raise SystemExit(f"no DICOM series found in {args.dicom_dir}")

    if args.all_series:
        for sid in series_ids:
            convert_series(args.dicom_dir, sid, args.output / f"{sid}.nii.gz")
    else:
        if len(series_ids) > 1:
            print(f"warning: {len(series_ids)} series present, converting the first. "
                  "Use --all-series to convert them all.")
        convert_series(args.dicom_dir, series_ids[0], args.output)


if __name__ == "__main__":
    main()
