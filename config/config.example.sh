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
# Scratch space used by the MATLAB icosphere resampling step
export WMBA_TMP_DIR="${WMBA_TMP_DIR:-$WMBA_ROOT/work/tmp}"
# Directory holding the raw FLAIR NIfTIs, named <image_id>.nii.gz
export WMBA_FLAIR_DIR="${WMBA_FLAIR_DIR:-$WMBA_ROOT/work/flair}"
# Directory holding the raw T1 NIfTIs, named <image_id>.nii.gz
export WMBA_T1_DIR="${WMBA_T1_DIR:-$WMBA_ROOT/work/t1}"
# FreeSurfer recon-all output root (bin/00_recon_all.sh writes here)
export WMBA_FS_DIR="${WMBA_FS_DIR:-$WMBA_ROOT/work/freesurfer}"

# --- pipeline parameters ---------------------------------------------------
# Laplacian iso-levels to extract. 1 = superficial (just under the WM/GM
# boundary), 8 = deep (close to the ventricle). See wmba/marching_cube.py:LAP_VAL.
export WMBA_LEVELS="${WMBA_LEVELS:-1 2 3 4 5 6 7 8}"
export WMBA_HEMIS="${WMBA_HEMIS:-lh rh}"
# Icosphere subdivision order. 6 -> 40962 vertices per hemisphere.
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

# --- MATLAB ----------------------------------------------------------------
export WMBA_MATLAB="${WMBA_MATLAB:-matlab}"
# Directory containing SurfStat + the FreeSurfer MATLAB helpers
# (SurfStatReadSurf1, read_surf, write_curv, read_curv, freesurfer_read_tri,
#  writeObjMesh2, MeshNormal).
export WMBA_MATLAB_MODULES="${WMBA_MATLAB_MODULES:-/path/to/matlab_modules}"
# Directory containing the icosphere templates ic<order>.tri
export WMBA_ICO_DIR="${WMBA_ICO_DIR:-/path/to/freesurfer_scripts}"
# Path to the mri_surf2ico.sh wrapper
export WMBA_SURF2ICO="${WMBA_SURF2ICO:-/path/to/freesurfer_scripts/mri_surf2ico.sh}"

# --- optional: WMH segmentation (external Singularity image) ---------------
# Leave empty to skip bin/05_wmh_segmentation.sh
export WMBA_WMHSEG_SIF="${WMBA_WMHSEG_SIF:-}"
export WMBA_WMHSEG_SCRIPT="${WMBA_WMHSEG_SCRIPT:-}"
export WMBA_WMHSEG_BIND="${WMBA_WMHSEG_BIND:-$WMBA_DATA_DIR}"

# --- optional: SynthSeg ----------------------------------------------------
# Leave empty to skip bin/06_synthseg.sh
export WMBA_SYNTHSEG_PREDICT="${WMBA_SYNTHSEG_PREDICT:-}"
export WMBA_SYNTHSEG_PYTHON="${WMBA_SYNTHSEG_PYTHON:-$WMBA_PYTHON}"
