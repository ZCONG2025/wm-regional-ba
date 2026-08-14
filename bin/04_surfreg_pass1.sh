#!/usr/bin/env bash
# Stage 4 - register a subject's spheres to the first-pass template, producing
# <hemi>.sphere.reg0 at every level.
#
#   bin/04_surfreg_pass1.sh <subject> <session> <hemi>
#
# Only needed for the subjects that go into the second-pass template.
#
# Original: III_SurfReg1.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <session> <hemi>" >&2; exit 2; }
[[ $# -eq 3 ]] || usage

subject="$1"; session="$2"; hemi="$3"
session_dir="$(wmba_session_dir "$subject" "$session")"

wmba_setup_freesurfer

for level in $WMBA_LEVELS; do
  mid="$session_dir/midsurf/lvl$level"
  [[ -f "$mid/$hemi.sphere.reg0" ]] && continue

  wmba_log "surfreg pass 1: $subject/$session $hemi lvl$level"
  cp -f "$mid"/* "$session_dir/surf/"

  mris_register \
    "$session_dir/surf/$hemi.sphere" \
    "$WMBA_TEMPLATE_DIR/${hemi}lvl${level}.tif" \
    "$session_dir/surf/$hemi.sphere.reg0"

  mv -f "$session_dir/surf"/* "$mid/"
  mv -f "$mid"/*.lvl* "$session_dir/surf/"
done
