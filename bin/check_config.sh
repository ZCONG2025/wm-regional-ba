#!/usr/bin/env bash
# Preflight: check that everything config/config.sh points at actually exists
# and works, before you burn a day of cluster time finding out it doesn't.
#
#   bin/check_config.sh
#
# Exits 0 if the core pipeline can run, 1 if a required item is missing.
# Optional stages (WMH segmentation, SynthSeg, cluster submission) are reported
# but never cause a failure.
WMBA_SKIP_VALIDATE=1   # report an invalid levels/hemis setting, do not die on it
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

# common.sh sets -e; here we want to run every check and report at the end.
set +e

pass=0; warn=0; fail=0

ok()   { printf '  \033[32mOK\033[0m    %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; fail=$((fail+1)); }
note() { printf '  \033[33mSKIP\033[0m  %s\n' "$*"; warn=$((warn+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

check_dir()  { if [[ -d "${2:-}" ]]; then ok "$1: $2"; else bad "$1 is not a directory: ${2:-<unset>}"; fi; }
check_file() { if [[ -f "${2:-}" ]]; then ok "$1: $2"; else bad "$1 is not a file: ${2:-<unset>}"; fi; }

# Output directories are created here if absent -- the pipeline needs them, and
# finding out they are unwritable now beats finding out mid-run.
check_writable() {
  local label="$1" dir="$2"
  if mkdir -p "$dir" 2>/dev/null && [[ -w "$dir" ]]; then
    ok "$label writable: $dir"
  else
    bad "$label not writable (and could not be created): $dir"
  fi
}

# ---------------------------------------------------------------------------
head_ "Configuration source"
if [[ -f "$WMBA_ROOT/config/config.sh" ]]; then
  ok "config/config.sh"
else
  bad "config/config.sh missing -- run: cp config/config.example.sh config/config.sh"
fi

# ---------------------------------------------------------------------------
head_ "Levels and hemispheres"
validate_msg="$(wmba_validate_config 2>&1)"
if [[ -z "$validate_msg" ]]; then
  n_lv=$(echo $WMBA_LEVELS | wc -w); n_h=$(echo $WMBA_HEMIS | wc -w)
  ok "WMBA_LEVELS='$WMBA_LEVELS'  WMBA_HEMIS='$WMBA_HEMIS'  -> $((n_lv*n_h)) features per scan"
else
  # here-string, not a pipe: a pipe would run the loop in a subshell and the
  # failure counter would never reach the parent, breaking the exit code.
  while IFS= read -r line; do
    bad "${line#ERROR: }"
  done <<< "$validate_msg"
fi

# ---------------------------------------------------------------------------
head_ "Working directories"
check_writable "data dir      (WMBA_DATA_DIR)"     "$WMBA_DATA_DIR"
check_writable "template dir  (WMBA_TEMPLATE_DIR)" "$WMBA_TEMPLATE_DIR"
check_writable "scratch dir   (WMBA_TMP_DIR)"      "$WMBA_TMP_DIR"
check_writable "FreeSurfer out(WMBA_FS_DIR)"       "$WMBA_FS_DIR"
check_dir      "T1 input dir  (WMBA_T1_DIR)"       "$WMBA_T1_DIR"
check_dir      "FLAIR input   (WMBA_FLAIR_DIR)"    "$WMBA_FLAIR_DIR"

# ---------------------------------------------------------------------------
head_ "FreeSurfer"
if [[ ! -d "${FREESURFER_HOME:-}" ]]; then
  bad "FREESURFER_HOME is not a directory: ${FREESURFER_HOME:-<unset>}"
else
  ok "FREESURFER_HOME: $FREESURFER_HOME"
  check_file "setup script" "$FREESURFER_HOME/SetUpFreeSurfer.sh"

  if [[ -f "$FREESURFER_HOME/license.txt" ]]; then
    ok "licence: $FREESURFER_HOME/license.txt"
  elif [[ -n "${FS_LICENSE:-}" && -f "$FS_LICENSE" ]]; then
    ok "licence: \$FS_LICENSE -> $FS_LICENSE"
  else
    bad "no FreeSurfer licence. Register free at https://surfer.nmr.mgh.harvard.edu/registration.html, then put license.txt in \$FREESURFER_HOME or set \$FS_LICENSE"
  fi

  if (set +u; source "$FREESURFER_HOME/SetUpFreeSurfer.sh" >/dev/null 2>&1); then
    for tool in recon-all mri_convert mris_smooth mris_inflate mris_sphere \
                mris_curvature mris_register mris_make_template; do
      if (set +u; source "$FREESURFER_HOME/SetUpFreeSurfer.sh" >/dev/null 2>&1
          command -v "$tool" >/dev/null); then
        ok "tool: $tool"
      else
        bad "tool not found after sourcing FreeSurfer: $tool"
      fi
    done
    ver=$(cat "$FREESURFER_HOME/build-stamp.txt" 2>/dev/null || echo "unknown")
    printf '  \033[36mINFO\033[0m  version: %s\n' "$ver"
    printf '  \033[36mINFO\033[0m  developed against 7.1.0 -- record your version in the methods\n'
  else
    bad "could not source $FREESURFER_HOME/SetUpFreeSurfer.sh"
  fi
fi

# ---------------------------------------------------------------------------
head_ "FSL (stage 07 only)"
if [[ ! -d "${FSLDIR:-}" ]]; then
  bad "FSLDIR is not a directory: ${FSLDIR:-<unset>}"
else
  ok "FSLDIR: $FSLDIR"
  for tool in bet flirt; do
    if [[ -x "$FSLDIR/bin/$tool" ]] || command -v "$tool" >/dev/null; then
      ok "tool: $tool"
    else
      bad "tool not found: $tool"
    fi
  done
fi

# ---------------------------------------------------------------------------
head_ "Python"
if ! command -v "$WMBA_PYTHON" >/dev/null; then
  bad "WMBA_PYTHON not executable: $WMBA_PYTHON"
else
  ok "interpreter: $(command -v "$WMBA_PYTHON") ($("$WMBA_PYTHON" --version 2>&1))"
  # The probe prints a sentinel so an interpreter that produces no output at all
  # (a stub, a broken shim) is reported as a failure rather than as "no missing
  # packages".
  probe=$("$WMBA_PYTHON" - <<'PY' 2>/dev/null
mods = ["numpy", "scipy", "nibabel", "mne", "skimage", "trimesh", "torch"]
bad = []
for m in mods:
    try:
        __import__(m)
    except Exception:
        bad.append(m)
print("WMBA_PROBE:" + ",".join(bad))
PY
)
  if [[ "$probe" != WMBA_PROBE:* ]]; then
    bad "\$WMBA_PYTHON produced no output -- it is not a working interpreter: $WMBA_PYTHON"
  else
    missing="${probe#WMBA_PROBE:}"
    if [[ -z "$missing" ]]; then
      ok "dependencies: numpy scipy nibabel mne skimage trimesh torch"
    else
      bad "missing python packages: ${missing//,/ }  (pip install -e . or conda env create -f environment.yml)"
    fi
  fi
  if "$WMBA_PYTHON" -c "import wmba" >/dev/null 2>&1; then
    ok "wmba package importable"
  else
    bad "cannot 'import wmba' -- run: pip install -e ."
  fi
fi

# ---------------------------------------------------------------------------
head_ "MATLAB (stages 06 and 07)"
if ! command -v "$WMBA_MATLAB" >/dev/null; then
  bad "WMBA_MATLAB not on PATH: $WMBA_MATLAB"
else
  ok "matlab: $(command -v "$WMBA_MATLAB")"
fi
check_dir "MATLAB modules (WMBA_MATLAB_MODULES)" "$WMBA_MATLAB_MODULES"
if [[ -d "${WMBA_MATLAB_MODULES:-}" ]]; then
  for fn in SurfStatReadSurf1 read_surf write_curv read_curv \
            freesurfer_read_tri writeObjMesh2 MeshNormal; do
    if find "$WMBA_MATLAB_MODULES" -maxdepth 3 -name "$fn.m" -print -quit 2>/dev/null | grep -q .; then
      ok "matlab function: $fn.m"
    else
      bad "matlab function not found under \$WMBA_MATLAB_MODULES: $fn.m"
    fi
  done
fi
check_file "mri_surf2ico (WMBA_SURF2ICO)" "$WMBA_SURF2ICO"
check_file "icosphere template ic${WMBA_ICO_ORDER}.tri" "$WMBA_ICO_DIR/ic${WMBA_ICO_ORDER}.tri"

# ---------------------------------------------------------------------------
head_ "Template"
missing_tif=0
for hemi in $WMBA_HEMIS; do
  for lv in $WMBA_LEVELS; do
    [[ -f "$WMBA_TEMPLATE_DIR/${hemi}lvl${lv}_1.tif" ]] || missing_tif=$((missing_tif+1))
  done
done
n_expected=$(( $(echo $WMBA_HEMIS | wc -w) * $(echo $WMBA_LEVELS | wc -w) ))
if [[ $missing_tif -eq 0 ]]; then
  ok "all $n_expected second-pass templates present in $WMBA_TEMPLATE_DIR"
else
  note "$missing_tif of $n_expected second-pass templates missing -- you must build a template first (docs/pipeline.md, stages 03-05) before running bin/run_subject.sh"
fi

# ---------------------------------------------------------------------------
head_ "Optional stages"
if [[ -n "${WMBA_WMHSEG_SIF:-}" ]]; then
  check_file "WMH segmentation image" "$WMBA_WMHSEG_SIF"
else
  note "WMH segmentation not configured (stage 08 will be skipped)"
fi
if [[ -n "${WMBA_SYNTHSEG_PREDICT:-}" ]]; then
  check_file "SynthSeg predict script" "$WMBA_SYNTHSEG_PREDICT"
else
  note "SynthSeg not configured (stage 09 will be skipped)"
fi
if command -v qsub >/dev/null; then
  if [[ -f "$WMBA_ROOT/cluster/queue.conf" ]]; then
    ok "SGE available, cluster/queue.conf present"
  else
    note "SGE available but no cluster/queue.conf -- cp cluster/queue.conf.example cluster/queue.conf"
  fi
else
  note "qsub not found (single-machine use; cluster/ scripts unused)"
fi

# ---------------------------------------------------------------------------
printf '\n\033[1m%d passed, %d skipped, %d failed\033[0m\n' "$pass" "$warn" "$fail"
if [[ $fail -gt 0 ]]; then
  echo "Fix the FAIL items in config/config.sh before running the pipeline." >&2
  exit 1
fi
echo "Core pipeline is ready."
