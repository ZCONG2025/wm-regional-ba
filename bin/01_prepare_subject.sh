#!/usr/bin/env bash
# Stage 1 - stage the FreeSurfer outputs this pipeline needs into the working
# directory layout, and produce the T1 NIfTI used for FLAIR co-registration.
#
#   bin/01_prepare_subject.sh <subject> [scan]
#
# Reads  : $WMBA_FS_DIR/<subject>/0/{mri,surf}
# Writes : $WMBA_DATA_DIR/<subject>/<scan>/{aseg.mgz,brain.mgz,?h.white,T1.nii.gz}
#
# Original: the first half of run1.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> [scan]" >&2; exit 2; }
[[ $# -ge 1 ]] || usage

subject="$1"
scan="${2:-0}"

wmba_setup_freesurfer

fs_dir="$WMBA_FS_DIR/$subject/0"
out_dir="$(wmba_scan_dir "$subject" "$scan")"

[[ -d "$fs_dir" ]] || wmba_die "FreeSurfer output not found: $fs_dir (run 00_recon_all.sh first)"

mkdir -p "$out_dir/mask"

for f in mri/aseg.mgz mri/brain.mgz surf/lh.white surf/rh.white; do
  [[ -f "$fs_dir/$f" ]] || wmba_die "missing FreeSurfer output: $fs_dir/$f"
  cp -f "$fs_dir/$f" "$out_dir/$(basename "$f")"
done

if [[ ! -f "$out_dir/T1.nii.gz" ]]; then
  mri_convert "$out_dir/brain.mgz" "$out_dir/T1.nii.gz"
fi

wmba_log "prepared $out_dir"
