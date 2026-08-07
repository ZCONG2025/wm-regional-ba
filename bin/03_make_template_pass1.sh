#!/usr/bin/env bash
# Stage 3 - seed the surface registration templates from a single subject.
#
#   bin/03_make_template_pass1.sh <hemi> [subject/scan]
#
# Writes : $WMBA_TEMPLATE_DIR/<hemi>lvl<level>.tif   for each level
#
# Run once per hemisphere when you build a new template. Subjects processed
# against an existing template do not need this.
# See https://surfer.nmr.mgh.harvard.edu/fswiki/SurfaceRegAndTemplates
#
# Original: II_MakeFirstTemp.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <hemi> [subject/scan]" >&2; exit 2; }
[[ $# -ge 1 ]] || usage

hemi="$1"
seed="${2:-$WMBA_TEMPLATE_SEED}"

[[ "$seed" == */* ]] || wmba_die "seed must be '<subject>/<scan>', got: $seed"

wmba_setup_freesurfer
export SUBJECTS_DIR="$WMBA_DATA_DIR"
mkdir -p "$WMBA_TEMPLATE_DIR"

seed_dir="$WMBA_DATA_DIR/$seed"
[[ -d "$seed_dir" ]] || wmba_die "seed subject not found: $seed_dir"

for level in $WMBA_LEVELS; do
  wmba_log "template pass 1: $hemi lvl$level (seed $seed)"

  # mris_make_template only looks in <subject>/surf, so stage the level in.
  cp -f "$seed_dir/midsurf/lvl$level"/* "$seed_dir/surf/"

  mris_make_template -sdir "$WMBA_DATA_DIR" "$hemi" sphere "$seed" \
    "$WMBA_TEMPLATE_DIR/${hemi}lvl${level}.tif"

  mv -f "$seed_dir/surf"/* "$seed_dir/midsurf/lvl$level/"
  mv -f "$seed_dir/midsurf/lvl$level"/*.lvl* "$seed_dir/surf/"
done
