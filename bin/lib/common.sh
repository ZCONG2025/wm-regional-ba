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

# Run MATLAB in batch mode on a snippet passed via stdin.
wmba_matlab() {
  wmba_require_cmd "$WMBA_MATLAB"
  local mpath="$WMBA_ROOT/matlab:$WMBA_MATLAB_MODULES"
  MATLABPATH="${mpath}${MATLABPATH:+:$MATLABPATH}" \
    "$WMBA_MATLAB" -nodisplay -nosplash -nodesktop
}
