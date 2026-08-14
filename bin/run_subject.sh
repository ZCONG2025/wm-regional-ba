#!/usr/bin/env bash
# End-to-end driver for one subject against an EXISTING template.
#
#   bin/run_subject.sh <subject> <t1_id> <flair_id> [session]
#
# <t1_id> and <flair_id> are image identifiers, resolved as
# $WMBA_T1_DIR/<t1_id>.nii.gz and $WMBA_FLAIR_DIR/<flair_id>.nii.gz.
#
# Runs, for every hemisphere in $WMBA_HEMIS and every level in $WMBA_LEVELS:
#   00 recon-all -> 01 prepare -> 02 iso-surface -> 06 register + icosphere
#   -> 07 FLAIR sampling
#
# Every step is skipped when its output already exists, so re-running after a
# failure resumes rather than restarts.
#
# Building a template from scratch is a separate, one-off job -- see
# docs/pipeline.md, stages 03 to 05.
#
# Original: run1.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <t1_id> <flair_id> [session]" >&2; exit 2; }
[[ $# -ge 3 ]] || usage

subject="$1"; t1_id="$2"; flair_id="$3"; scan="${4:-0}"
scan_dir="$(wmba_scan_dir "$subject" "$scan")"

if [[ ! -f "$WMBA_FS_DIR/$subject/0/mri/aseg.mgz" ]]; then
  "$WMBA_ROOT/bin/00_recon_all.sh" "$subject" "$t1_id"
fi

if [[ ! -f "$scan_dir/T1.nii.gz" ]]; then
  "$WMBA_ROOT/bin/01_prepare_subject.sh" "$subject" "$scan"
fi

for level in $WMBA_LEVELS; do
  mid="$scan_dir/midsurf/lvl$level"
  for hemi in $WMBA_HEMIS; do
    feature="$mid/${flair_id}_${hemi}.txt"
    if [[ -f "$feature" ]]; then
      wmba_log "skip $subject/$scan $hemi lvl$level (feature exists)"
      continue
    fi

    if [[ ! -f "$scan_dir/surf/$hemi.lvl$level" && ! -f "$mid/$hemi.sphere" ]]; then
      "$WMBA_ROOT/bin/02_make_isosurf.sh" "$subject" "$scan" "$hemi" "$level"
    fi

    if [[ ! -f "$mid/${hemi}_lvl${level}_ico_${WMBA_ICO_ORDER}" ]]; then
      "$WMBA_ROOT/bin/06_surfreg_pass2.sh" "$subject" "$scan" "$hemi" "$level"
    fi

    "$WMBA_ROOT/bin/07_sampling.sh" "$subject" "$scan" "$hemi" "$level" "$flair_id"
  done
done

wmba_log "done: $subject/$scan"
