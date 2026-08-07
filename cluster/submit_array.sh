#!/usr/bin/env bash
# Submit a generated array job to Sun Grid Engine.
#
#   cluster/submit_array.sh <job_script> <num_tasks> [max_concurrent]
#
# Site-specific queue/host selection goes in cluster/queue.conf (git-ignored):
#
#   WMBA_QUEUE="all.q"
#   WMBA_QSUB_EXTRA="-l h_vmem=16G -pe smp 2"
#
# The original ArrRun.sh pinned ~250 named compute nodes of one specific
# cluster; that list has no meaning anywhere else and was removed.
set -euo pipefail

WMBA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() { echo "usage: $(basename "$0") <job_script> <num_tasks> [max_concurrent]" >&2; exit 2; }
[[ $# -ge 2 ]] || usage

job_script="$1"
num_tasks="$2"
max_concurrent="${3:-50}"

[[ -f "$job_script" ]] || { echo "no such job script: $job_script" >&2; exit 1; }
command -v qsub >/dev/null || { echo "qsub not found -- not on an SGE cluster?" >&2; exit 1; }

WMBA_QUEUE=""
WMBA_QSUB_EXTRA=""
if [[ -f "$WMBA_ROOT/cluster/queue.conf" ]]; then
  # shellcheck source=/dev/null
  source "$WMBA_ROOT/cluster/queue.conf"
fi

log_dir="$WMBA_ROOT/logs"
mkdir -p "$log_dir"

# shellcheck disable=SC2086
qsub \
  ${WMBA_QUEUE:+-q "$WMBA_QUEUE"} \
  ${WMBA_QSUB_EXTRA} \
  -N "$(basename "$job_script" .arr)" \
  -o "$log_dir" \
  -e "$log_dir" \
  -cwd \
  -t "1-${num_tasks}" \
  -tc "$max_concurrent" \
  "$job_script"
