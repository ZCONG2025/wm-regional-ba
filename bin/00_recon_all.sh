#!/usr/bin/env bash
# Stage 0 - FreeSurfer cortical reconstruction.
#
#   bin/00_recon_all.sh <subject> <t1_image_id>
#
# Reads  : $WMBA_FLAIR_DIR/../<t1_image_id>.nii.gz  (see --t1 override below)
# Writes : $WMBA_FS_DIR/<subject>/0/{mri/aseg.mgz, mri/brain.mgz, surf/?h.white}
#
# Original: RUN_FS_seg.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <t1_nifti>" >&2; exit 2; }
[[ $# -eq 2 ]] || usage

subject="$1"
t1_file="$2"

[[ -f "$t1_file" ]] || wmba_die "T1 image not found: $t1_file"

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
