#!/usr/bin/env bash
# Extract one iso-potential surface and take it through the standard FreeSurfer
# smooth -> inflate -> sphere chain so it can be registered like a cortical
# surface.
#
#   bin/lib/template_and_reg.sh <subject> <session> <level> <hemi>
#
# Writes : <session_dir>/surf/<hemi>.lvl<level>
#          <session_dir>/midsurf/lvl<level>/{<hemi>.smoothwm,.inflated,.sphere,.inflated.H,.inflated.K}
#
# Original: TemplateAndReg.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <session> <level> <hemi>" >&2; exit 2; }
[[ $# -eq 4 ]] || usage

subject="$1"; session="$2"; level="$3"; hemi="$4"
session_dir="$(wmba_session_dir "$subject" "$session")"

wmba_setup_freesurfer

wmba_log "marching cubes: $subject/$session $hemi lvl$level"
"$WMBA_PYTHON" -m wmba.marching_cube \
  --subject "$subject" --session "$session" --hemi "$hemi" --level "$level"

mkdir -p "$session_dir/surf" "$session_dir/midsurf/lvl$level"

surf="$session_dir/surf"
mris_smooth   "$surf/$hemi.lvl$level" "$surf/$hemi.smoothwm"
mris_inflate  "$surf/$hemi.smoothwm"  "$surf/$hemi.inflated"
mris_sphere   "$surf/$hemi.inflated"  "$surf/$hemi.sphere"
mris_curvature -w "$surf/$hemi.inflated"

# Park everything except the iso-surface itself under midsurf/lvl<level>/ so the
# next level can reuse surf/ as a scratch area. mris_* only ever reads from surf/.
mv -f "$surf"/* "$session_dir/midsurf/lvl$level/"
mv -f "$session_dir/midsurf/lvl$level"/*.lvl* "$surf/"
