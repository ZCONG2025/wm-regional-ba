#!/usr/bin/env bash
# Stage 6 - register a subject to the cohort template (-> <hemi>.sphere.reg1) and
# resample the mid-surface onto a standard icosphere, so every subject ends up
# with the same vertex count and the same vertex ordering.
#
#   bin/06_surfreg_pass2.sh <subject> <session> <hemi> <level>
#
# Writes : <session_dir>/midsurf/lvl<level>/<hemi>_lvl<level>_ico_<order>
#          (a FreeSurfer binary surface, 40962 vertices at order 6)
#
# Original: III_SurfReg2.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <session> <hemi> <level>" >&2; exit 2; }
[[ $# -eq 4 ]] || usage

subject="$1"; session="$2"; hemi="$3"; level="$4"
session_dir="$(wmba_session_dir "$subject" "$session")"
mid="$session_dir/midsurf/lvl$level"

wmba_setup_freesurfer

template="$WMBA_TEMPLATE_DIR/${hemi}lvl${level}_1.tif"
[[ -f "$template" ]] || wmba_die "template not found: $template (see docs/pipeline.md)"
[[ -f "$session_dir/brain.mgz" ]] || wmba_die "missing $session_dir/brain.mgz (run 01_prepare_subject.sh)"

cp -f "$mid"/* "$session_dir/surf/"

wmba_log "surfreg pass 2: $subject/$session $hemi lvl$level"
mris_register \
  "$session_dir/surf/$hemi.sphere" \
  "$template" \
  "$session_dir/surf/$hemi.sphere.reg1"

# --- resample onto the icosphere -------------------------------------------
# mri_surf2surf carries the mid-surface's own xyz coordinates through the
# spherical registration and writes them out on the icosahedron's topology.
# --sval-xyz/--tval-xyz do the whole thing in one call: no per-axis overlays, no
# separate topology file, no mesh reassembly.
#
# Layout note: the working tree is <data>/<subject>/<session>/surf, so pointing
# SUBJECTS_DIR at <data>/<subject> makes <session> the "subject" as far as
# FreeSurfer is concerned, and no staging copy is needed.
#
# "ico" is special-cased inside mri_surf2surf: it loads
# $FREESURFER_HOME/lib/bem/ic<order>.tri directly, so no ico subject directory
# and no target registration are required.
out="$mid/${hemi}_lvl${level}_ico_${WMBA_ICO_ORDER}"

wmba_log "icosphere resample: $subject/$session $hemi lvl$level -> order $WMBA_ICO_ORDER"
SUBJECTS_DIR="$WMBA_DATA_DIR/$subject" \
mri_surf2surf \
  --hemi "$hemi" \
  --srcsubject "$session" \
  --srcsurfreg "sphere.reg1" \
  --sval-xyz "lvl$level" \
  --trgsubject ico \
  --trgicoorder "$WMBA_ICO_ORDER" \
  --tval-xyz "$session_dir/brain.mgz" \
  --tval "$out"

[[ -s "$out" ]] || wmba_die "mri_surf2surf produced no output: $out"

mv -f "$session_dir/surf"/* "$mid/"
mv -f "$mid"/*.lvl* "$session_dir/surf/"
