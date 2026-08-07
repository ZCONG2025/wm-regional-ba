#!/usr/bin/env bash
# Stage 4 - register a subject's spheres to the first-pass template, producing
# <hemi>.sphere.reg0 at every level.
#
#   bin/04_surfreg_pass1.sh <subject> <scan> <hemi>
#
# Only needed for the subjects that go into the second-pass template.
#
# Original: III_SurfReg1.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <scan> <hemi>" >&2; exit 2; }
[[ $# -eq 3 ]] || usage

subject="$1"; scan="$2"; hemi="$3"
scan_dir="$(wmba_scan_dir "$subject" "$scan")"

wmba_setup_freesurfer

for level in $WMBA_LEVELS; do
  mid="$scan_dir/midsurf/lvl$level"
  [[ -f "$mid/$hemi.sphere.reg0" ]] && continue

  wmba_log "surfreg pass 1: $subject/$scan $hemi lvl$level"
  cp -f "$mid"/* "$scan_dir/surf/"

  mris_register \
    "$scan_dir/surf/$hemi.sphere" \
    "$WMBA_TEMPLATE_DIR/${hemi}lvl${level}.tif" \
    "$scan_dir/surf/$hemi.sphere.reg0"

  mv -f "$scan_dir/surf"/* "$mid/"
  mv -f "$mid"/*.lvl* "$scan_dir/surf/"
done
