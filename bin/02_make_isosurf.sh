#!/usr/bin/env bash
# Stage 2 - generate one white-matter iso-surface (a "mid-surface") for one
# hemisphere at one Laplacian level, plus its spherical parameterisation.
#
#   bin/02_make_isosurf.sh <subject> <scan> <hemi> <level>
#
# Idempotent: skips work whose output already exists.
#
# Original: I_MakeIsoSurf.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <scan> <hemi> <level>" >&2; exit 2; }
[[ $# -eq 4 ]] || usage

subject="$1"; scan="$2"; hemi="$3"; level="$4"
scan_dir="$(wmba_scan_dir "$subject" "$scan")"

mkdir -p "$scan_dir/surf" "$scan_dir/midsurf" "$scan_dir/mask"

# The Laplacian field is level-independent, so it is solved once per hemisphere.
if [[ ! -f "$scan_dir/mask/lap_$hemi.nii" ]]; then
  "$WMBA_ROOT/bin/lib/mask_and_lap.sh" "$subject" "$scan" "$hemi"
fi

if [[ ! -f "$scan_dir/surf/$hemi.lvl$level" ]]; then
  "$WMBA_ROOT/bin/lib/template_and_reg.sh" "$subject" "$scan" "$level" "$hemi"
fi
