#!/usr/bin/env bash
# Build the Laplacian domain mask and solve the Laplace equation inside it.
#
#   bin/lib/mask_and_lap.sh <subject> <scan> <hemi>
#
# Writes : <scan_dir>/mask/lap_mask_<hemi>.nii   (1 = ventricle, 2 = WM, 3 = outside)
#          <scan_dir>/mask/lap_<hemi>.nii        (potential field, 0 .. 10000)
#
# Original: MaskAndLap.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <scan> <hemi>" >&2; exit 2; }
[[ $# -eq 3 ]] || usage

subject="$1"; scan="$2"; hemi="$3"

wmba_log "masking: $subject/$scan $hemi"
"$WMBA_PYTHON" -m wmba.masking   --subject "$subject" --scan "$scan" --hemi "$hemi"

wmba_log "laplacian: $subject/$scan $hemi"
"$WMBA_PYTHON" -m wmba.laplacian --subject "$subject" --scan "$scan" --hemi "$hemi"
