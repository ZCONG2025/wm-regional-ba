#!/usr/bin/env bash
# Stage 0 - FreeSurfer cortical reconstruction.
#
#   bin/00_recon_all.sh <subject> <t1_id>
#
# Reads  : $WMBA_T1_DIR/<t1_id>.nii.gz
# Writes : $WMBA_FS_DIR/<subject>/0/{mri/aseg.mgz, mri/brain.mgz, surf/?h.white}
#
# Original: RUN_FS_seg.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <t1_id>" >&2; exit 2; }
[[ $# -eq 2 ]] || usage

subject="$1"
t1_id="$2"
t1_file="$WMBA_T1_DIR/$t1_id.nii.gz"

[[ -f "$t1_file" ]] || wmba_die "T1 image not found: $t1_file (expected \$WMBA_T1_DIR/<t1_id>.nii.gz)"

wmba_setup_freesurfer

subjects_dir="$WMBA_FS_DIR/$subject"
mkdir -p "$subjects_dir"

# recon-all -all: full pipeline, including subcortical segmentation (aseg.mgz)
# and white surfaces, which are the only outputs the rest of this pipeline uses.
wmba_log "recon-all: $subject"
recon-all \
  -sd "$subjects_dir" \
  -s 0 \
  -i "$t1_file" \
  -all
