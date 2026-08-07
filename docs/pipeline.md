# The pipeline

## What it computes

Cortical brain-age models sample features on the cortical surface. There is no
equivalent surface in the white matter — it is a solid volume, not a sheet. This
pipeline manufactures one: it solves the Laplace equation between the lateral
ventricle and the WM/GM boundary, then takes eight iso-potential surfaces
through that field. They nest like the layers of an onion, they never
self-intersect, and every one of them can be spherically parameterised and
registered exactly like a cortical surface.

The result is a fixed set of vertices — 8 levels × 2 hemispheres × 40962
vertices — where vertex *i* at level *l* refers to the same white-matter
location in every subject. FLAIR intensity sampled at those vertices is the
feature vector that goes into a regional white-matter brain age model.

```
   WM/GM boundary   V = 10000   <- FreeSurfer ?h.white, rasterised
        level 1     V =  9995
        level 2     V =  9970
        level 3     V =  9880
        level 4     V =  9500
        level 5     V =  8700
        level 6     V =  7300
        level 7     V =  6000
        level 8     V =  5000
    lateral vent.   V =     0   <- aseg label 4 (lh) / 43 (rh)
```

The iso-values are not evenly spaced because the potential is not linear in
depth; they were chosen so the surfaces come out roughly evenly spaced in the
white matter.

## Stages

```
                       per subject
  ┌──────────────────────────────────────────────────────────────┐
  │ 00 recon_all         T1 ──► aseg.mgz, ?h.white               │
  │ 01 prepare_subject   stage into <data>/<subj>/<scan>/         │
  │                                                               │
  │        per hemisphere                                         │
  │ 02 make_isosurf      ├─ masking.py     ──► lap_mask_?h.nii   │
  │                      ├─ laplacian.py   ──► lap_?h.nii        │
  │                      │      per level                         │
  │                      ├─ marching_cube  ──► ?h.lvl<N>         │
  │                      └─ mris_smooth / inflate / sphere        │
  └──────────────────────────────────────────────────────────────┘
                              │
                   ┌──────────┴───────────┐
      build a template (once)      use an existing template
                   │                      │
  03 make_template_pass1  seed subject     │
  04 surfreg_pass1        cohort ► reg0    │
  05 make_template_pass2  cohort ► *_1.tif │
                   └──────────┬───────────┘
                              │
  06 surfreg_pass2      ?h.sphere ► ?h.sphere.reg1, resample to icosphere
  07 sampling           FLAIR ► <flair_id>_?h.txt        ◄── the output
                              │
  08 wmh_segmentation   optional, external tool
  09 synthseg           optional, external tool
```

Stages 03–05 follow FreeSurfer's standard two-pass template recipe
(<https://surfer.nmr.mgh.harvard.edu/fswiki/SurfaceRegAndTemplates>): seed a
template from one subject, register a cohort to it, then rebuild the template
from the whole registered cohort. **You only do this once.** Everyone processing
subjects against an existing template runs 00 → 02, then 06 → 07, which is what
`bin/run_subject.sh` does.

## Running it

### One subject, existing template

```bash
bin/run_subject.sh SUBJ01 /path/to/T1.nii.gz I123456 0
```

Arguments: subject id, T1 NIfTI, FLAIR image id (the basename in
`$WMBA_FLAIR_DIR`), and scan/session id. Every step is skipped if its output
exists, so rerunning after a failure resumes.

### A cohort on an SGE cluster

```bash
python cluster/make_array_job.py subjects.tsv jobs/cohort.arr
cluster/submit_array.sh jobs/cohort.arr 300 50
```

`subjects.tsv` is `<subject> <t1_image_id> <flair_image_id> [scan]`, one per
line. Parallelise across subjects only — see `docs/known_issues.md` §3.

### Building a template from scratch

```bash
# 1. every candidate subject through stage 02 first
for s in $(cut -f1 template_cohort.tsv); do
  bin/02_make_isosurf.sh "$s" 0 lh 1   # ... and every level/hemi
done

# 2. seed
export WMBA_TEMPLATE_SEED=SUBJ0001/0
bin/03_make_template_pass1.sh lh
bin/03_make_template_pass1.sh rh

# 3. register the cohort to the seed template
for s in $(cut -f1 template_cohort.tsv); do
  bin/04_surfreg_pass1.sh "$s" 0 lh
  bin/04_surfreg_pass1.sh "$s" 0 rh
done

# 4. rebuild from the whole cohort
cp config/template_subjects.example.txt config/template_subjects.txt   # then edit
bin/05_make_template_pass2.sh lh
bin/05_make_template_pass2.sh rh
```

Steps 1 and 3 are the ones to put on a cluster; each is hours per subject.

## Checking progress

```bash
python tools/check_completion.py --stage sphere            # stage 02 done?
python tools/check_completion.py --stage obj               # stage 06 done?
python tools/check_completion.py --stage feature --flair-id I123456
```

Exit status is non-zero if anything is missing, so it works in a script.

## Output format

`<data>/<subject>/<scan>/midsurf/lvl<N>/<flair_id>_<hemi>.txt` — one float per
line, in icosphere vertex order, 40962 lines at order 6. Load with
`numpy.loadtxt`. Vertex *i* is the same anatomical location in every subject, so
a cohort stacks straight into an (n_subjects, 40962) matrix.
