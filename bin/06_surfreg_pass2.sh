#!/usr/bin/env bash
# Stage 6 - register a subject to the cohort template (-> <hemi>.sphere.reg1) and
# resample the mid-surface onto a standard icosphere, so every subject ends up
# with the same vertex count and the same vertex ordering.
#
#   bin/06_surfreg_pass2.sh <subject> <scan> <hemi> <level>
#
# Writes : <scan_dir>/midsurf/lvl<level>/<hemi>_lvl<level>_ico_<order>
#          (a FreeSurfer binary surface, 40962 vertices at order 6)
#
# Original: III_SurfReg2.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <scan> <hemi> <level>" >&2; exit 2; }
[[ $# -eq 4 ]] || usage

subject="$1"; scan="$2"; hemi="$3"; level="$4"
scan_dir="$(wmba_scan_dir "$subject" "$scan")"
mid="$scan_dir/midsurf/lvl$level"

wmba_setup_freesurfer

template="$WMBA_TEMPLATE_DIR/${hemi}lvl${level}_1.tif"
[[ -f "$template" ]] || wmba_die "template not found: $template (see docs/pipeline.md)"
[[ -f "$scan_dir/brain.mgz" ]] || wmba_die "missing $scan_dir/brain.mgz (run 01_prepare_subject.sh)"

cp -f "$mid"/* "$scan_dir/surf/"

wmba_log "surfreg pass 2: $subject/$scan $hemi lvl$level"
mris_register \
  "$scan_dir/surf/$hemi.sphere" \
  "$template" \
  "$scan_dir/surf/$hemi.sphere.reg1"

# --- resample onto the icosphere -------------------------------------------
# mri_surf2surf carries the mid-surface's own xyz coordinates through the
# spherical registration and writes them out on the icosahedron's topology.
# --sval-xyz/--tval-xyz do the whole thing in one call: no per-axis overlays, no
# separate topology file, no mesh reassembly.
#
# Layout note: the working tree is <data>/<subject>/<scan>/surf, so pointing
# SUBJECTS_DIR at <data>/<subject> makes <scan> the "subject" as far as
# FreeSurfer is concerned, and no staging copy is needed.
#
# "ico" is special-cased inside mri_surf2surf: it loads
# $FREESURFER_HOME/lib/bem/ic<order>.tri directly, so no ico subject directory
# and no target registration are required.
out="$mid/${hemi}_lvl${level}_ico_${WMBA_ICO_ORDER}"

wmba_log "icosphere resample: $subject/$scan $hemi lvl$level -> order $WMBA_ICO_ORDER"
SUBJECTS_DIR="$WMBA_DATA_DIR/$subject" \
mri_surf2surf \
  --hemi "$hemi" \
  --srcsubject "$scan" \
  --srcsurfreg "sphere.reg1" \
  --sval-xyz "lvl$level" \
  --trgsubject ico \
  --trgicoorder "$WMBA_ICO_ORDER" \
  --tval-xyz "$scan_dir/brain.mgz" \
  --tval "$out"

[[ -s "$out" ]] || wmba_die "mri_surf2surf produced no output: $out"

mv -f "$scan_dir/surf"/* "$mid/"
mv -f "$mid"/*.lvl* "$scan_dir/surf/"
