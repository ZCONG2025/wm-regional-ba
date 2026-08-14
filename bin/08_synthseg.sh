#!/usr/bin/env bash
# Stage 8 (optional) - SynthSeg segmentation of the T1, used for QC and for
# alternative subcortical labels.
#
#   bin/08_synthseg.sh <subject> <session>
#
# SynthSeg is not distributed here. Point $WMBA_SYNTHSEG_PREDICT at your copy of
# SynthSeg_predict.py (it also ships inside FreeSurfer >= 7.3 as `mri_synthseg`).
#
# Writes : <session_dir>/SynthSeg.nii.gz
#
# Original: 0_Synthseg.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <session>" >&2; exit 2; }
[[ $# -eq 2 ]] || usage

subject="$1"; session="$2"
session_dir="$(wmba_session_dir "$subject" "$session")"

if [[ -z "${WMBA_SYNTHSEG_PREDICT:-}" ]]; then
  wmba_die "SynthSeg is not configured. Set WMBA_SYNTHSEG_PREDICT in config/config.sh, or skip this stage."
fi

[[ -f "$session_dir/T1.nii.gz" ]] || wmba_die "missing $session_dir/T1.nii.gz"

wmba_log "SynthSeg: $subject/$session"
"$WMBA_SYNTHSEG_PYTHON" "$WMBA_SYNTHSEG_PREDICT" \
  --i "$session_dir/T1.nii.gz" \
  --o "$session_dir/SynthSeg.nii.gz" \
  --v1
