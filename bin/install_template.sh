#!/usr/bin/env bash
# Install a pre-built surface registration template into $WMBA_TEMPLATE_DIR.
#
#   bin/install_template.sh <directory | archive.tar.gz | archive.zip>
#
# Use this when someone hands you a template instead of building your own
# (docs/pipeline.md, stages 03-05). Verifies that every hemisphere/level file the
# pipeline will ask for is present before copying anything, so a partial
# template fails here rather than three hours into a run.
#
# Required:  <hemi>lvl<level>_1.tif   for every $WMBA_HEMIS x $WMBA_LEVELS
# Optional:  <hemi>lvl<level>.tif     first-pass templates; only needed if you
#                                     intend to extend the template cohort
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() { echo "usage: $(basename "$0") <directory | archive.tar.gz | archive.zip>" >&2; exit 2; }
[[ $# -eq 1 ]] || usage

src="$1"
[[ -e "$src" ]] || wmba_die "no such file or directory: $src"

# --- unpack archives into a scratch dir -----------------------------------
staged=""
cleanup() { [[ -n "$staged" && -d "$staged" ]] && rm -rf "$staged"; }
trap cleanup EXIT

if [[ -d "$src" ]]; then
  search_root="$src"
else
  staged="$(mktemp -d "${TMPDIR:-/tmp}/wmba-template.XXXXXX")"
  case "$src" in
    *.tar.gz|*.tgz) tar -xzf "$src" -C "$staged" ;;
    *.tar)          tar -xf  "$src" -C "$staged" ;;
    *.zip)          wmba_require_cmd unzip; unzip -q "$src" -d "$staged" ;;
    *) wmba_die "unrecognised archive type: $src (expected .tar.gz, .tar or .zip)" ;;
  esac
  search_root="$staged"
fi

# --- locate and verify ----------------------------------------------------
# Templates are often nested one directory deep inside an archive.
find_tif() {
  find "$search_root" -maxdepth 3 -name "$1" -type f -print -quit 2>/dev/null
}

missing=()
found_required=()
for hemi in $WMBA_HEMIS; do
  for lv in $WMBA_LEVELS; do
    f="$(find_tif "${hemi}lvl${lv}_1.tif")"
    if [[ -n "$f" ]]; then
      found_required+=("$f")
    else
      missing+=("${hemi}lvl${lv}_1.tif")
    fi
  done
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "ERROR: template is incomplete for WMBA_HEMIS='$WMBA_HEMIS' WMBA_LEVELS='$WMBA_LEVELS'" >&2
  echo "       missing ${#missing[@]} file(s):" >&2
  printf '         %s\n' "${missing[@]}" >&2
  echo "       If this template was built for a different set of levels, set" >&2
  echo "       WMBA_LEVELS in config/config.sh to match it." >&2
  exit 1
fi

found_optional=()
for hemi in $WMBA_HEMIS; do
  for lv in $WMBA_LEVELS; do
    f="$(find_tif "${hemi}lvl${lv}.tif")"
    [[ -n "$f" ]] && found_optional+=("$f")
  done
done

# --- install --------------------------------------------------------------
mkdir -p "$WMBA_TEMPLATE_DIR"
for f in "${found_required[@]}" "${found_optional[@]}"; do
  cp -f "$f" "$WMBA_TEMPLATE_DIR/$(basename "$f")"
done

wmba_log "installed ${#found_required[@]} second-pass template(s) into $WMBA_TEMPLATE_DIR"
if [[ ${#found_optional[@]} -gt 0 ]]; then
  wmba_log "also installed ${#found_optional[@]} first-pass template(s)"
else
  wmba_log "no first-pass (<hemi>lvl<N>.tif) templates in the source -- fine unless you plan to extend the template cohort"
fi
echo
echo "Verify with: bin/check_config.sh"
echo "Then run:    bin/run_subject.sh <subject> <t1_nifti> <flair_id> [scan]"
