#!/usr/bin/env bash
# Stage 2 - generate one white-matter iso-surface (a "mid-surface") for one
# hemisphere at one Laplacian level, plus its spherical parameterisation.
#
#   bin/02_make_isosurf.sh <subject> <session> <hemi> <level>
#
# Idempotent: skips work whose output already exists.
#
# Original: I_MakeIsoSurf.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <session> <hemi> <level>" >&2; exit 2; }
[[ $# -eq 4 ]] || usage

subject="$1"; session="$2"; hemi="$3"; level="$4"
session_dir="$(wmba_session_dir "$subject" "$session")"

mkdir -p "$session_dir/surf" "$session_dir/midsurf" "$session_dir/mask"

# The Laplacian field is level-independent, so it is solved once per hemisphere.
if [[ ! -f "$session_dir/mask/lap_$hemi.nii" ]]; then
  "$WMBA_ROOT/bin/lib/mask_and_lap.sh" "$subject" "$session" "$hemi"
fi

if [[ ! -f "$session_dir/surf/$hemi.lvl$level" ]]; then
  "$WMBA_ROOT/bin/lib/template_and_reg.sh" "$subject" "$session" "$level" "$hemi"
fi
