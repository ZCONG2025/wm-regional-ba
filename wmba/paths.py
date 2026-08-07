"""Working-directory layout and the CLI arguments shared by every stage.

All stages operate on a single scan directory:

    $WMBA_DATA_DIR/<subject>/<scan>/
        aseg.mgz                    from FreeSurfer
        brain.mgz                   from FreeSurfer
        lh.white  rh.white          from FreeSurfer
        T1.nii.gz                   mri_convert of brain.mgz
        mask/
            lap_mask_<hemi>.nii     Laplacian domain   (masking.py)
            lap_<hemi>.nii          Laplacian field    (laplacian.py)
        surf/
            <hemi>.lvl<level>       iso-surface        (marching_cube.py)
        midsurf/lvl<level>/
            <hemi>.sphere, .sphere.reg0, .sphere.reg1, ...
            <hemi>_lvl<level>_ico_<order>.obj
            <hemi>_coord.mat
            <flair_id>_<hemi>.txt   sampled feature    (sampling.py)
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path


def data_root(explicit: str | None = None) -> Path:
    """Resolve $WMBA_DATA_DIR, or the --data-dir override."""
    root = explicit or os.environ.get("WMBA_DATA_DIR")
    if not root:
        raise SystemExit(
            "No data directory. Pass --data-dir, or set WMBA_DATA_DIR "
            "(see config/config.example.sh)."
        )
    return Path(root)


def scan_dir(data_dir: Path, subject: str, scan: str) -> Path:
    return data_dir / str(subject) / str(scan)


def add_common_args(parser: argparse.ArgumentParser) -> argparse.ArgumentParser:
    parser.add_argument("--subject", required=True, help="subject identifier")
    parser.add_argument("--scan", default="0", help="scan/session identifier (default: 0)")
    parser.add_argument("--hemi", required=True, choices=["lh", "rh"], help="hemisphere")
    parser.add_argument(
        "--data-dir",
        default=None,
        help="working directory root (default: $WMBA_DATA_DIR)",
    )
    return parser


def resolve(args) -> Path:
    """Return the scan directory for a parsed argument namespace."""
    return scan_dir(data_root(args.data_dir), args.subject, args.scan)
