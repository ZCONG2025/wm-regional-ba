#!/usr/bin/env bash
# Stage 5 - build the final surface registration templates from the whole
# template cohort, using the pass-1 registrations (sphere.reg0).
#
#   bin/05_make_template_pass2.sh <hemi> [subject_list]
#
# subject_list: one "<subject>/<scan>" per line. Defaults to
#               $WMBA_TEMPLATE_SUBJECTS (config/template_subjects.txt).
#
# Writes : $WMBA_TEMPLATE_DIR/<hemi>lvl<level>_1.tif   for each level
#
# Original: II_MakeSecondTemp.sh -- the cohort was hard-coded there as ~400
# subject IDs on one line; it now lives in a data file you supply.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <hemi> [subject_list]" >&2; exit 2; }
[[ $# -ge 1 ]] || usage

hemi="$1"
list_file="${2:-$WMBA_TEMPLATE_SUBJECTS}"

[[ -f "$list_file" ]] || wmba_die "template subject list not found: $list_file"

mapfile -t subjects < <(grep -vE '^\s*(#|$)' "$list_file")
[[ ${#subjects[@]} -gt 0 ]] || wmba_die "template subject list is empty: $list_file"

wmba_setup_freesurfer
export SUBJECTS_DIR="$WMBA_DATA_DIR"
mkdir -p "$WMBA_TEMPLATE_DIR"

wmba_log "template pass 2: $hemi, ${#subjects[@]} subjects"

for level in $WMBA_LEVELS; do
  out="$WMBA_TEMPLATE_DIR/${hemi}lvl${level}_1.tif"
  wmba_log "  lvl$level -> $(basename "$out")"

  # -surf_dir makes mris_make_template read <subject>/midsurf/lvl<N>/ directly,
  # so no staging into surf/ is needed here.
  mris_make_template \
    -surf_dir "midsurf/lvl$level/" \
    "$hemi" sphere.reg0 \
    "${subjects[@]}" \
    "$out"
done
