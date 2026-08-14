#!/usr/bin/env bash
# Stage 7 - co-register the FLAIR to the subject's T1 (once per scan) and sample
# FLAIR intensity at every vertex of one icosphere-resampled mid-surface.
#
#   bin/07_sampling.sh <subject> <scan> <hemi> <level> <flair_id>
#
# Reads  : $WMBA_FLAIR_DIR/<flair_id>.nii.gz
# Writes : <scan_dir>/<flair_id>_FLAIR_converted.nii.gz
#          <scan_dir>/midsurf/lvl<level>/<hemi>_coord.mat
#          <scan_dir>/midsurf/lvl<level>/<flair_id>_<hemi>.txt   <- the feature
#
# Original: IV_sampling.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <scan> <hemi> <level> <flair_id>" >&2; exit 2; }
[[ $# -eq 5 ]] || usage

subject="$1"; scan="$2"; hemi="$3"; level="$4"; flair_id="$5"
scan_dir="$(wmba_scan_dir "$subject" "$scan")"

flair_src="$WMBA_FLAIR_DIR/$flair_id.nii.gz"
flair_reg="$scan_dir/${flair_id}_FLAIR_converted.nii.gz"

# --- FLAIR preprocessing, once per (scan, flair_id) ------------------------
if [[ ! -f "$flair_reg" ]]; then
  [[ -f "$flair_src" ]] || wmba_die "FLAIR not found: $flair_src"
  [[ -f "$scan_dir/T1.nii.gz" ]] || wmba_die "T1 not found: $scan_dir/T1.nii.gz (run 01_prepare_subject.sh)"

  wmba_setup_fsl
  wmba_log "FLAIR skull-strip + rigid registration to T1: $subject/$scan $flair_id"

  bet "$flair_src" "$scan_dir/${flair_id}_FLAIR_converted_brain.nii.gz"

  # T1.nii.gz comes from brain.mgz, i.e. it is already conformed 256^3 and
  # skull-stripped, so the sampled coordinates are in FreeSurfer voxel space.
  flirt \
    -in  "$scan_dir/${flair_id}_FLAIR_converted_brain.nii.gz" \
    -ref "$scan_dir/T1.nii.gz" \
    -out "$flair_reg" \
    -omat "$scan_dir/${flair_id}_flair_trans_converted.mat"
fi

# --- sample -----------------------------------------------------------------
# Vertex coordinates are read straight from the surface written by stage 06.
wmba_log "sampling: $subject/$scan $hemi lvl$level $flair_id"
"$WMBA_PYTHON" -m wmba.sampling \
  --subject "$subject" --scan "$scan" --hemi "$hemi" \
  --level "$level" --flair "$flair_id"
