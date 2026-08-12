# Where every original file went

The original `script/` directory held 66 files: the pipeline itself, one-off
scratch scripts, generated cluster job files, and a copy of the study's subject
data. This table records what happened to each of them, so nothing looks like it
vanished by accident.

## Pipeline — kept and rewritten

| Original | Now | What changed |
|---|---|---|
| `RUN_FS_seg.sh` | `bin/00_recon_all.sh` | paths from config; removed `source /ifshome/<user>/.bash_profile`; checks for a FreeSurfer licence |
| first half of `run1.sh` | `bin/01_prepare_subject.sh` | split out; fails loudly on missing FreeSurfer outputs instead of copying nothing |
| `I_MakeIsoSurf.sh` | `bin/02_make_isosurf.sh` | paths from config; `mkdir -p` instead of bare `mkdir` |
| `II_MakeFirstTemp.sh` | `bin/03_make_template_pass1.sh` | hemisphere and seed subject are arguments, not edited-in-place variables; `#!/bin/bas` typo fixed; dropped `chmod -R 777` |
| `III_SurfReg1.sh` | `bin/04_surfreg_pass1.sh` | per-level skip instead of one all-or-nothing check on level 4; dropped `chmod -R 777` |
| `II_MakeSecondTemp.sh` | `bin/05_make_template_pass2.sh` | the ~400 hard-coded subject IDs moved to `config/template_subjects.txt`; `#!/bin/bas` typo fixed |
| `III_SurfReg2.sh` | `bin/06_surfreg_pass2.sh` | MATLAB invoked through `wmba_matlab` with `MATLABPATH` from config, instead of a heredoc with absolute paths |
| `MaskAndLap.sh` | `bin/lib/mask_and_lap.sh` | conda activation replaced by `$WMBA_PYTHON` |
| `TemplateAndReg.sh` | `bin/lib/template_and_reg.sh` | same |
| `IV_sampling.sh` | `bin/07_sampling.sh` | dropped the second, redundant `flirt` call (it re-applied the matrix the first call had just produced, with identical output); dead `dicom2nifti` lines removed |
| `0_Synthseg.sh` | `bin/08_synthseg.sh` | paths from config; the PPMI paths it carried were unused |
| `run1.sh` | `bin/run_subject.sh` | same resume logic, rewritten as a loop over hemispheres instead of two copy-pasted blocks |
| `masking.py` | `wmba/masking.py` | paths as arguments; volume shape read from the image instead of assuming 256³; named constants for the label values |
| `laplacian.py` | `wmba/laplacian.py` | paths as arguments; `--max-iters` / `--tol` exposed with the original values as defaults; per-iteration print throttled |
| `marching_cube.py` | `wmba/marching_cube.py` | paths as arguments; creates `surf/` if absent; validates the level |
| `sampling.py` | `wmba/sampling.py` | paths as arguments; removed a broken `from script.utils.file_handler import ...` (that module was never in the repo, and its imports were unused); vertex count derived from the mesh instead of hard-coded 40962; **see `docs/known_issues.md` for the subcortical masking behaviour** |
| `utils_new.py` | `wmba/mesh_utils.py` | kept the functions the pipeline uses; `aggregate_from_indices` now honours `mode="nearest"` instead of silently doing bilinear |
| `obj_convert.m` | `matlab/obj_convert.m` | icosphere order from the environment; raises instead of printing an id on missing input |
| `ResampleMesh2Icosphere_FreeSurfer.m` | `matlab/ResampleMesh2Icosphere_FreeSurfer.m` | hard-coded `addpath` and tool paths replaced by config; `eval('!...')` replaced by `system` with error checking; temp dir cleaned via `onCleanup` so a failure does not leave it behind. **Provenance unresolved — see `NOTICE`.** |
| `CheckIDs.py`, `II_ClearData.py` | `tools/check_completion.py` | merged into one generic completeness check over any stage |
| `DICOM2NIFTI.py`, `for_python.ksh` | `tools/dicom_to_nifti.py` | turned into a real CLI; `for_python.ksh` called `spec2nii` (an MR *spectroscopy* converter) on a site-specific tree and is not reproducible elsewhere |

## Subject data — deliberately not included

| Original | Why it is not here |
|---|---|
| `srcs/ADNI_all.csv` | ADNI clinical table: subject id, sex, weight, research group, **APOE genotype**, study date, age, MMSE, GDS, CDR, FAQ, NPI-Q. Redistribution is prohibited by the ADNI Data Use Agreement. |
| `srcs/*.xlsx`, `srcs/*.txt` | Subject id lists, scan dates and derived cohorts from the same source. |
| `control_all.txt`, `control_all.xlsx` | Subject id lists. |
| `additional_ALL*.txt.arr`, `effective_all_followup_run1.txt.arr` | Generated cluster job files that embed subject ids. |

Every user of this pipeline applies for the data themselves. `.gitignore` blocks
these file types so they cannot be committed by accident.

## Dropped — dead, broken or one-off

| Original | Why |
|---|---|
| `DetermineFolder.py` | empty file (0 bytes) |
| `RunWithConsole.py` | `SyntaxError` on line 11 (unclosed parenthesis); the rest duplicated `laplacian.py` with a different volume shape |
| `RSLMesh2Icosphere_run.m` | uses `and` where MATLAB needs `&&`, so it cannot run; also a hard-coded `1:4026` loop over another study |
| `pathdef.m` | 88 KB dump of one machine's MATLAB search path |
| `obj2FS.m`, `tmp.m`, `temp.py`, `temp.sh` | scratch snippets with absolute paths to single files |
| `ClearCache.py` | busy-loop deleting two hard-coded log files; the log paths are now per-job under `logs/` |
| `0_FreeSurfer.sh` | sets up the FreeSurfer environment and then does nothing |
| `run0.sh`, `run2.sh` | earlier drivers superseded by `run1.sh` → `bin/run_subject.sh` |
| `0_SortOutIDs.py` | walks another lab member's dataset tree to build one cohort's id list |
| `O_datamanagement.m` | cohort bookkeeping with hard-coded row counts (`1:1020`, `1:211`, `1:809`) against ADNI clinical tables |
| `WMHcal.py` | despite the name it does not calculate WMH — it copies `lobes+aseg.mgz` for one cohort |
| `V_WMHcalculation.sh` | calls `WMHcal.py` with `$CASE` and `$scanid`, neither of which it sets, and passes three arguments `WMHcal.py` does not accept. The stage was never functional. |
| `V_WMHsegmentation.sh` | wrapped a third-party WMH segmentation container that is not this project's work. Nothing in the pipeline read its `WMH.nii.gz` output. Use whatever WMH tool you prefer, separately. |
| `ArrRun.sh`, `ArrRun1.sh`, `QsubArray.py` | Sun Grid Engine job submission. Schedulers differ too much between sites for this to be worth shipping, and `ArrRun.sh` existed mainly to pin ~250 named compute nodes of one specific cluster. Wrap `bin/run_subject.sh` in whatever your site uses — see the README. |

If you want any of these back, they are in the original `script/` folder — this
repository is a fresh directory, nothing was moved or deleted there.
