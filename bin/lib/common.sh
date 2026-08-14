#!/usr/bin/env bash
# Shared bootstrap for every script in bin/. Sourced, never executed.
#
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

set -euo pipefail

WMBA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export WMBA_ROOT

if [[ -f "$WMBA_ROOT/config/config.sh" ]]; then
  # shellcheck source=/dev/null
  source "$WMBA_ROOT/config/config.sh"
elif [[ -f "$WMBA_ROOT/config/config.example.sh" ]]; then
  echo "WARNING: config/config.sh not found, falling back to config.example.sh" >&2
  echo "         Run: cp config/config.example.sh config/config.sh" >&2
  # shellcheck source=/dev/null
  source "$WMBA_ROOT/config/config.example.sh"
else
  echo "ERROR: no configuration found under $WMBA_ROOT/config/" >&2
  exit 1
fi

wmba_log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }

wmba_die() { echo "ERROR: $*" >&2; exit 1; }

# Levels outside 1..8 are not supported: LAP_VAL defines iso-values for 0 and 9,
# but level 0 sits essentially on the WM surface and marching cubes there is
# often degenerate, level 9 runs into the ventricle, and the published template
# covers 1..8 only. Validated here so a bad setting fails at once rather than
# hours in.
WMBA_VALID_LEVELS="1 2 3 4 5 6 7 8"
WMBA_VALID_HEMIS="lh rh"

wmba_validate_config() {
  local bad=() lv hemi
  for lv in ${WMBA_LEVELS:-}; do
    [[ " $WMBA_VALID_LEVELS " == *" $lv "* ]] || bad+=("level '$lv'")
  done
  for hemi in ${WMBA_HEMIS:-}; do
    [[ " $WMBA_VALID_HEMIS " == *" $hemi "* ]] || bad+=("hemisphere '$hemi'")
  done
  [[ -n "${WMBA_LEVELS:-}" ]] || bad+=("WMBA_LEVELS is empty")
  [[ -n "${WMBA_HEMIS:-}"  ]] || bad+=("WMBA_HEMIS is empty")

  if [[ ${#bad[@]} -gt 0 ]]; then
    printf 'ERROR: unsupported configuration: %s\n' "$(IFS=', '; echo "${bad[*]}")" >&2
    printf '       WMBA_LEVELS must be a subset of: %s\n' "$WMBA_VALID_LEVELS" >&2
    printf '       WMBA_HEMIS  must be a subset of: %s\n' "$WMBA_VALID_HEMIS" >&2
    return 1
  fi
  return 0
}

# check_config.sh sets WMBA_SKIP_VALIDATE so it can report this alongside its
# other checks instead of dying before it prints anything.
if [[ -z "${WMBA_SKIP_VALIDATE:-}" ]]; then
  wmba_validate_config || exit 1
fi

# Load the FreeSurfer environment. Idempotent.
wmba_setup_freesurfer() {
  [[ -d "${FREESURFER_HOME:-}" ]] || wmba_die "FREESURFER_HOME is not a directory: ${FREESURFER_HOME:-<unset>}"
  if [[ -z "${FREESURFER:-}" ]]; then
    # FreeSurferEnv.sh is not -u clean.
    set +u
    # shellcheck source=/dev/null
    source "$FREESURFER_HOME/SetUpFreeSurfer.sh" >/dev/null
    set -u
  fi
  [[ -f "$FREESURFER_HOME/license.txt" || -n "${FS_LICENSE:-}" ]] || \
    wmba_die "FreeSurfer license not found. Put license.txt in \$FREESURFER_HOME or set \$FS_LICENSE."
}

# Load the FSL environment (needed only by 04_sampling.sh).
wmba_setup_fsl() {
  [[ -d "${FSLDIR:-}" ]] || wmba_die "FSLDIR is not a directory: ${FSLDIR:-<unset>}"
  export FSLOUTPUTTYPE="${FSLOUTPUTTYPE:-NIFTI_GZ}"
  set +u
  # shellcheck source=/dev/null
  source "$FSLDIR/etc/fslconf/fsl.sh"
  set -u
  export PATH="$FSLDIR/bin:$PATH"
}

# Absolute path to a subject/scan working directory.
wmba_scan_dir() {
  local subject="$1" scan="$2"
  echo "$WMBA_DATA_DIR/$subject/$scan"
}

wmba_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || wmba_die "required command not on PATH: $1"
}

