#!/usr/bin/env python3
"""Report which subject / session / level / hemisphere outputs are still missing.

    python tools/check_completion.py --flair-id I123456
    python tools/check_completion.py --subjects subjects.tsv --stage resampled

Prints one line per incomplete session, and a summary. Exit status is 1 if anything
is missing, so it can gate a downstream step.

Replaces the ad-hoc CheckIDs.py / II_ClearData.py loops, which hard-coded one
cohort's paths and file names.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

STAGES = {
    # stage name -> filename template relative to <session_dir>
    "lap": "mask/lap_{hemi}.nii",
    "surf": "surf/{hemi}.lvl{level}",
    "sphere": "midsurf/lvl{level}/{hemi}.sphere",
    "reg": "midsurf/lvl{level}/{hemi}.sphere.reg1",
    "resampled": "midsurf/lvl{level}/{hemi}_lvl{level}_ico_{order}",
    "feature": "midsurf/lvl{level}/{flair_id}_{hemi}.txt",
}


def parse_levels(spec: str) -> list[int]:
    return [int(x) for x in spec.replace(",", " ").split()]


def iter_sessions(data_dir: Path, subject_list: Path | None):
    if subject_list is not None:
        for line in subject_list.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            fields = line.split()
            subject = fields[0]
            session = fields[3] if len(fields) > 3 else "0"
            flair = fields[2] if len(fields) > 2 else None
            yield subject, session, flair
    else:
        for subj_dir in sorted(p for p in data_dir.iterdir() if p.is_dir()):
            for sess_path in sorted(p for p in subj_dir.iterdir() if p.is_dir()):
                yield subj_dir.name, sess_path.name, None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data-dir", default=os.environ.get("WMBA_DATA_DIR"))
    parser.add_argument("--subjects", type=Path, default=None,
                        help="whitespace-separated subject list, one per line: "
                             "<subject> <t1_id> <flair_id> [session]; "
                             "default: walk --data-dir")
    parser.add_argument("--stage", default="feature", choices=sorted(STAGES),
                        help="which output to check for (default: feature)")
    parser.add_argument("--levels", default=os.environ.get("WMBA_LEVELS", "1 2 3 4 5 6 7 8"))
    parser.add_argument("--hemis", default=os.environ.get("WMBA_HEMIS", "lh rh"))
    parser.add_argument("--order", default=os.environ.get("WMBA_ICO_ORDER", "6"))
    parser.add_argument("--flair-id", default=None,
                        help="required for --stage feature when --subjects is not given")
    parser.add_argument("--quiet", action="store_true", help="print only the summary")
    args = parser.parse_args()

    if not args.data_dir:
        parser.error("pass --data-dir or set WMBA_DATA_DIR")
    data_dir = Path(args.data_dir)
    if not data_dir.is_dir():
        parser.error(f"not a directory: {data_dir}")

    template = STAGES[args.stage]
    levels = parse_levels(args.levels)
    hemis = args.hemis.split()

    n_sessions = n_incomplete = n_missing = 0

    for subject, session, list_flair in iter_sessions(data_dir, args.subjects):
        n_sessions += 1
        session_dir = data_dir / subject / session
        flair_id = list_flair or args.flair_id
        if "{flair_id}" in template and not flair_id:
            parser.error("--stage feature needs --flair-id (or a 3-column --subjects file)")

        missing = []
        for level in levels:
            for hemi in hemis:
                rel = template.format(
                    hemi=hemi, level=level, order=args.order, flair_id=flair_id
                )
                if not (session_dir / rel).is_file():
                    missing.append(rel)

        if missing:
            n_incomplete += 1
            n_missing += len(missing)
            if not args.quiet:
                print(f"{subject}\t{session}\tmissing {len(missing)}: {missing[0]}"
                      + (" ..." if len(missing) > 1 else ""))

    print(
        f"\n{n_sessions - n_incomplete}/{n_sessions} sessions complete for stage "
        f"'{args.stage}' ({n_missing} files missing)",
        file=sys.stderr,
    )
    return 1 if n_incomplete else 0


if __name__ == "__main__":
    raise SystemExit(main())
