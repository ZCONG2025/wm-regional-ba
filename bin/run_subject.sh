#!/usr/bin/env bash
# End-to-end driver for one subject against an EXISTING template.
#
#   bin/run_subject.sh <subject> <t1_id> <flair_id> [session]
#
# <t1_id> and <flair_id> are image identifiers, resolved as
# $WMBA_T1_DIR/<t1_id>.nii.gz and $WMBA_FLAIR_DIR/<flair_id>.nii.gz.
#
# Runs, for every hemisphere in $WMBA_HEMIS and every level in $WMBA_LEVELS:
#   00 recon-all -> 01 prepare -> 02 iso-surface -> 06 register + icosphere
#   -> 07 FLAIR sampling
#
# Every step is skipped when its output already exists, so re-running after a
# failure resumes rather than restarts.
#
# Building a template from scratch is a separate, one-off job -- see
# docs/pipeline.md, stages 03 to 05.
#
# Original: run1.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <subject> <t1_id> <flair_id> [session]" >&2; exit 2; }
[[ $# -ge 3 ]] || usage

subject="$1"; t1_id="$2"; flair_id="$3"; session="${4:-0}"
session_dir="$(wmba_session_dir "$subject" "$session")"

# recon-all output is per session. If it already exists the T1 is never read,
# and t1_id may be given as "-".
if [[ -f "$WMBA_FS_DIR/$subject/$session/mri/aseg.mgz" ]]; then
  wmba_log "using existing recon-all output: $WMBA_FS_DIR/$subject/$session"
else
  [[ "$t1_id" != "-" ]] || wmba_die \
    "t1_id is \"-\" but there is no recon-all output at $WMBA_FS_DIR/$subject/$session -- pass a T1 image id so stage 00 can run"
  "$WMBA_ROOT/bin/00_recon_all.sh" "$subject" "$t1_id" "$session"
fi

if [[ ! -f "$session_dir/T1.nii.gz" ]]; then
  "$WMBA_ROOT/bin/01_prepare_subject.sh" "$subject" "$session"
fi

# --- Laplace solve, one process per hemisphere ------------------------------
# This is the slow part (~35 min a hemisphere) and the only part that
# parallelises: it is per hemisphere and writes only into mask/, so the two
# hemispheres never touch the same file. Everything after this shares
# <session>/surf/ as scratch and must stay serial.
#
# Set WMBA_PARALLEL_HEMIS=0 to run them one after the other instead — worth doing
# on a memory-constrained node, since each process holds a few float64 copies of
# the conformed volume (~0.5 GB per hemisphere).
pids=(); solved=()
for hemi in $WMBA_HEMIS; do
  [[ -f "$session_dir/mask/lap_$hemi.nii" ]] && continue
  if [[ "${WMBA_PARALLEL_HEMIS:-1}" == "1" ]]; then
    "$WMBA_ROOT/bin/lib/mask_and_lap.sh" "$subject" "$session" "$hemi" &
    pids+=("$!"); solved+=("$hemi")
  else
    "$WMBA_ROOT/bin/lib/mask_and_lap.sh" "$subject" "$session" "$hemi"
  fi
done
if [[ ${#pids[@]} -gt 0 ]]; then
  wmba_log "solving Laplace field for ${solved[*]} in parallel (${#pids[@]} processes)"
  failed=""
  for i in "${!pids[@]}"; do
    wait "${pids[$i]}" || failed+=" ${solved[$i]}"
  done
  [[ -z "$failed" ]] || wmba_die "Laplace solve failed for:$failed (see the stage log above)"
fi

# --- everything below is serial: it shares <session>/surf/ ------------------
for level in $WMBA_LEVELS; do
  mid="$session_dir/midsurf/lvl$level"
  for hemi in $WMBA_HEMIS; do
    feature="$mid/${flair_id}_${hemi}.txt"
    if [[ -f "$feature" ]]; then
      wmba_log "skip $subject/$session $hemi lvl$level (feature exists)"
      continue
    fi

    if [[ ! -f "$session_dir/surf/$hemi.lvl$level" && ! -f "$mid/$hemi.sphere" ]]; then
      "$WMBA_ROOT/bin/02_make_isosurf.sh" "$subject" "$session" "$hemi" "$level"
    fi

    if [[ ! -f "$mid/${hemi}_lvl${level}_ico_${WMBA_ICO_ORDER}" ]]; then
      "$WMBA_ROOT/bin/06_surfreg_pass2.sh" "$subject" "$session" "$hemi" "$level"
    fi

    "$WMBA_ROOT/bin/07_sampling.sh" "$subject" "$session" "$hemi" "$level" "$flair_id"
  done
done

wmba_log "done: $subject/$session"
