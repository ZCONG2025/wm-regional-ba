#!/usr/bin/env bash
# Stage 8 (optional) - white matter hyperintensity segmentation.
#
#   bin/08_wmh_segmentation.sh <subject> <scan>
#
# This wraps an EXTERNAL segmentation tool that is not distributed with this
# repository. Point $WMBA_WMHSEG_SIF / $WMBA_WMHSEG_SCRIPT at your own
# installation, or replace this script with any T1+FLAIR -> WMH mask tool.
#
# Writes : <scan_dir>/WMH.nii.gz
#
# Original: V_WMHsegmentation.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <scan>" >&2; exit 2; }
[[ $# -eq 2 ]] || usage

subject="$1"; scan="$2"
scan_dir="$(wmba_scan_dir "$subject" "$scan")"

if [[ -z "${WMBA_WMHSEG_SIF:-}" || -z "${WMBA_WMHSEG_SCRIPT:-}" ]]; then
  wmba_die "WMH segmentation is not configured. Set WMBA_WMHSEG_SIF and WMBA_WMHSEG_SCRIPT in config/config.sh, or skip this stage."
fi

wmba_require_cmd singularity

[[ -f "$scan_dir/T1.nii.gz"    ]] || wmba_die "missing $scan_dir/T1.nii.gz"
[[ -f "$scan_dir/FLAIR.nii.gz" ]] || wmba_die "missing $scan_dir/FLAIR.nii.gz"

wmba_log "WMH segmentation: $subject/$scan"
singularity exec \
  -B "$WMBA_WMHSEG_BIND:$WMBA_WMHSEG_BIND" \
  "$WMBA_WMHSEG_SIF" \
  sh "$WMBA_WMHSEG_SCRIPT" \
  "$scan_dir/T1.nii.gz" \
  "$scan_dir/FLAIR.nii.gz" \
  "$scan_dir/WMH.nii.gz"
