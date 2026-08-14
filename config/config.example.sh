#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# WM-RegionalBA configuration.
#
#   cp config/config.example.sh config/config.sh   and edit the values below.
#
# config/config.sh is git-ignored, so site-specific paths never leave your
# machine. Every value can also be overridden by exporting it before you call
# a pipeline script.
# ---------------------------------------------------------------------------

# --- repository root (auto-detected, do not edit) --------------------------
WMBA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export WMBA_ROOT

# --- working directories ---------------------------------------------------
# Per-subject derivatives live in $WMBA_DATA_DIR/<subject>/<scan>/
export WMBA_DATA_DIR="${WMBA_DATA_DIR:-$WMBA_ROOT/work/data}"
# Surface templates (?hlvl?.tif, ?hlvl?_1.tif) produced by bin/02_*
export WMBA_TEMPLATE_DIR="${WMBA_TEMPLATE_DIR:-$WMBA_ROOT/work/template}"
# Directory holding the raw FLAIR NIfTIs, named <image_id>.nii.gz
export WMBA_FLAIR_DIR="${WMBA_FLAIR_DIR:-$WMBA_ROOT/work/flair}"
# Directory holding the raw T1 NIfTIs, named <image_id>.nii.gz
export WMBA_T1_DIR="${WMBA_T1_DIR:-$WMBA_ROOT/work/t1}"
# FreeSurfer recon-all output root (bin/00_recon_all.sh writes here)
export WMBA_FS_DIR="${WMBA_FS_DIR:-$WMBA_ROOT/work/freesurfer}"

# --- pipeline parameters ---------------------------------------------------
# Laplacian iso-levels to extract. 1 = superficial (just under the WM/GM
# boundary), 8 = deep (close to the ventricle). See wmba/marching_cube.py:LAP_VAL.
#
# ONLY 1..8 ARE SUPPORTED, and the pipeline refuses anything else. LAP_VAL also
# defines iso-values for 0 and 9, but 0 sits essentially on the WM surface where
# marching cubes is often degenerate, 9 reaches the ventricle, and the published
# template covers 1..8 only. Narrowing the set (e.g. "2 4 6 8") is fine and
# proportionally faster; widening it is not.
export WMBA_LEVELS="${WMBA_LEVELS:-1 2 3 4 5 6 7 8}"
# Both hemispheres. Only lh and rh are valid.
export WMBA_HEMIS="${WMBA_HEMIS:-lh rh}"
# Icosphere subdivision order. 6 -> 40962 vertices per hemisphere.
# mri_surf2surf reads the icosahedron from $FREESURFER_HOME/lib/bem/ic<order>.tri,
# which ships with FreeSurfer -- nothing extra to install.
export WMBA_ICO_ORDER="${WMBA_ICO_ORDER:-6}"
# Subject used to seed the first-pass surface template (bin/02_make_template_pass1.sh)
export WMBA_TEMPLATE_SEED="${WMBA_TEMPLATE_SEED:-SUBJECT_ID/0}"
# One "<subject>/<scan>" per line; used by bin/02_make_template_pass2.sh
export WMBA_TEMPLATE_SUBJECTS="${WMBA_TEMPLATE_SUBJECTS:-$WMBA_ROOT/config/template_subjects.txt}"

# --- external neuroimaging software ---------------------------------------
# Developed against FreeSurfer 7.1.0. Surface outputs are not identical across
# FreeSurfer major versions, so record whichever you use in your methods.
export FREESURFER_HOME="${FREESURFER_HOME:-/usr/local/freesurfer-7.1.0}"

# FreeSurfer needs a licence file (free, academic):
#   https://surfer.nmr.mgh.harvard.edu/registration.html
# Leave this unset if the file already sits at $FREESURFER_HOME/license.txt;
# set it if your licence lives elsewhere (e.g. a read-only shared install).
# export FS_LICENSE="/path/to/license.txt"

export FSLDIR="${FSLDIR:-/usr/local/fsl}"
# NIFTI_GZ is assumed throughout; the pipeline writes and expects .nii.gz.
export FSLOUTPUTTYPE="${FSLOUTPUTTYPE:-NIFTI_GZ}"

# Python interpreter that has the packages in requirements.txt installed.
# e.g. /path/to/conda/envs/wmba/bin/python
export WMBA_PYTHON="${WMBA_PYTHON:-python}"

# --- optional: SynthSeg ----------------------------------------------------
# Only used by bin/08_synthseg.sh, which produces a segmentation for QC. Nothing
# downstream reads it. Leave empty to skip that stage.
export WMBA_SYNTHSEG_PREDICT="${WMBA_SYNTHSEG_PREDICT:-}"
export WMBA_SYNTHSEG_PYTHON="${WMBA_SYNTHSEG_PYTHON:-$WMBA_PYTHON}"
