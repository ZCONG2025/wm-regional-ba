#!/usr/bin/env bash
# Stage 6 - register a subject to the final template (-> <hemi>.sphere.reg1) and
# resample the iso-surface onto a standard icosphere so every subject ends up
# with vertex-wise correspondence.
#
#   bin/06_surfreg_pass2.sh <subject> <scan> <hemi> <level>
#
# Writes : <scan_dir>/midsurf/lvl<level>/<hemi>_lvl<level>_ico_<order>.obj
#
# Original: III_SurfReg2.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <scan> <hemi> <level>" >&2; exit 2; }
[[ $# -eq 4 ]] || usage

subject="$1"; scan="$2"; hemi="$3"; level="$4"
scan_dir="$(wmba_scan_dir "$subject" "$scan")"
mid="$scan_dir/midsurf/lvl$level"

wmba_setup_freesurfer
mkdir -p "$WMBA_TMP_DIR"

template="$WMBA_TEMPLATE_DIR/${hemi}lvl${level}_1.tif"
[[ -f "$template" ]] || wmba_die "template not found: $template (run 05_make_template_pass2.sh)"

cp -f "$mid"/* "$scan_dir/surf/"

wmba_log "surfreg pass 2: $subject/$scan $hemi lvl$level"
mris_register \
  "$scan_dir/surf/$hemi.sphere" \
  "$template" \
  "$scan_dir/surf/$hemi.sphere.reg1"

wmba_log "icosphere resample (MATLAB): $subject/$scan $hemi lvl$level"
wmba_matlab <<EOF
ResampleMesh2Icosphere_FreeSurfer( ...
    '$WMBA_DATA_DIR', ...
    '$WMBA_TMP_DIR', ...
    '$subject', ...
    '$scan_dir/surf', ...
    '$hemi', ...
    'lvl$level', ...
    '$WMBA_ICO_ORDER', ...
    '$scan');
exit;
EOF

mv -f "$scan_dir/surf"/* "$mid/"
mv -f "$mid"/*.lvl* "$scan_dir/surf/"
