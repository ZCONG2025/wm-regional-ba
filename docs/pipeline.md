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
  06 surfreg_pass2      ?h.sphere ► ?h.sphere.reg1, mri_surf2surf ► icosphere
  07 sampling           FLAIR ► <flair_id>_?h.txt        ◄── the output
                              │
  08 synthseg           optional, external tool, QC only
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

### A cohort

Wrap `bin/run_subject.sh` in whatever your site's scheduler is; no submission
scripts ship with this repository. Parallelise across subjects only, never across
levels or hemispheres within a subject — see
[`known_issues.md`](known_issues.md) §3. Budget ~8–16 GB and up to a day per
scan, single-threaded.

## Obtaining a template

A template is a set of `<hemi>lvl<level>_1.tif` files in `$WMBA_TEMPLATE_DIR` —
16 of them for the default 2 hemispheres × 8 levels. Every subject is registered
to it, and that registration is what makes vertex *i* mean the same location
across subjects. **Nothing downstream works without one.**

They are not in the repository itself: they are large binaries, and `.gitignore`
blocks `*.tif` on purpose. The template used for the reference analysis is
published as a release asset:

```bash
curl -LO https://github.com/ZCONG2025/wm-regional-ba/releases/latest/download/wmba-template-adni399.tar.gz
bin/install_template.sh wmba-template-adni399.tar.gz
bin/check_config.sh                               # confirms all 16 are present
```

It was built from **399 ADNI subjects** (400 selected, one dropped for a failed
first-pass registration) and contains the `_1` cohort averages for levels 1–8,
both hemispheres. The single-subject seed templates are not included: they are
not needed to process subjects, and unlike a cohort average they carry one
individual's folding pattern. Building your own template makes its own seed
(stage 03).

**Its generalisation beyond ADNI is unmeasured.** ADNI is an ageing,
memory-clinic cohort with substantial white-matter pathology; a template is the
average folding pattern of whatever cohort built it. Registering a different
population to it will not fail — `mris_register` always returns a registration —
but a poor fit degrades vertex correspondence silently, which propagates into
attenuated or biased downstream results. Prefer [building your own](#building-a-template)
when you can, and treat use of the ADNI template on other data as an assumption
to defend rather than a default.

`install_template.sh` verifies the whole set before copying anything, so an
incomplete template fails immediately rather than three hours into a run. It also
installs the first-pass `<hemi>lvl<level>.tif` files if the source has them —
those are only needed if you intend to extend the template cohort later.

If you only have `_1.tif` files, that is enough to process subjects.

## Building a template

Only needed if no suitable template exists for your work. This follows
FreeSurfer's documented two-pass recipe
(<https://surfer.nmr.mgh.harvard.edu/fswiki/SurfaceRegAndTemplates>).

### Why two passes

A template is the average folding pattern of a cohort in spherical coordinates.
To average a cohort you must first align it — but aligning requires a template.
The two passes break that circularity:

1. **Seed.** Build a template from a *single* subject. It is arbitrary and
   biased toward that one anatomy, but it gives every other subject something to
   register to.
2. **Cohort average.** Register the whole cohort to the seed template, then
   rebuild the template from all of those registrations. The result is an
   average, and the individual seed's idiosyncrasies wash out.

### Naming convention

The suffix counts cohort-average generations, not passes:

| File | Built from | Used for |
|---|---|---|
| `<hemi>lvl<N>.tif` | the single seed subject | producing `sphere.reg0` |
| `<hemi>lvl<N>_1.tif` | the cohort, aligned by `sphere.reg0` | producing `sphere.reg1` |

Correspondingly, `<hemi>.sphere.reg0` is the registration to the seed and
`<hemi>.sphere.reg1` the registration to the cohort average.

**`_1` is the template subjects are processed against**, and `sphere.reg1` is
what the icosphere resampling in stage 06 consumes. That is one registration to
the cohort average per subject.

The convention extends: you can register the cohort to `_1`, average again into
`_2`, and register subjects to that. Whether the extra generation is worth the
compute is a judgement call, and the reference analysis did not use one — the
published results come from `_1`. If you do build a `_2`, point
`bin/06_surfreg_pass2.sh` at it and carry the change through `install_template.sh`
and `check_config.sh`, which both look for `_1` by name.

### What the original study used

For the reference implementation the seed was one arbitrarily chosen subject,
excluded from the second-pass cohort. The second pass then used **399**
subjects — 400 were selected, and one was dropped because its first-pass
registration failed. That attrition is normal; see
[`known_issues.md`](known_issues.md) §6.

A few hundred subjects is ample. More mostly costs runtime, and a subject whose
pass-1 registration failed must be excluded, because a bad surface in the
template degrades every registration made against it afterwards.

### Procedure

```bash
# 1. every candidate subject through stage 02, all hemispheres and levels.
#    This is the expensive part -- put it on a cluster.
for s in $(cut -f1 template_cohort.tsv); do
  for hemi in lh rh; do
    for lv in 1 2 3 4 5 6 7 8; do
      bin/02_make_isosurf.sh "$s" 0 "$hemi" "$lv"
    done
  done
done
python tools/check_completion.py --stage sphere   # drop whatever failed

# 2. seed the template from one subject
export WMBA_TEMPLATE_SEED=SUBJ0001/0
bin/03_make_template_pass1.sh lh
bin/03_make_template_pass1.sh rh

# 3. register the cohort to the seed template -> ?h.sphere.reg0
#    Also expensive; also a cluster job.
for s in $(cut -f1 template_cohort.tsv); do
  bin/04_surfreg_pass1.sh "$s" 0 lh
  bin/04_surfreg_pass1.sh "$s" 0 rh
done
python tools/check_completion.py --stage reg      # exclude failures from step 4

# 4. rebuild the template from the whole registered cohort -> ?hlvl?_1.tif
cp config/template_subjects.example.txt config/template_subjects.txt
$EDITOR config/template_subjects.txt              # one <subject>/<scan> per line
bin/05_make_template_pass2.sh lh
bin/05_make_template_pass2.sh rh
```

Steps 1 and 3 dominate the cost — hours per subject each. Steps 2 and 4 are
single jobs.

Keep `config/template_subjects.txt` even though it is git-ignored: it is the
only record of which subjects your template was built from, and a reviewer may
ask.

### After building

Once `$WMBA_TEMPLATE_DIR` holds all the `_1.tif` files, process subjects
normally with `bin/run_subject.sh` — it registers to the template and never
rebuilds it. Do not rebuild the template partway through a cohort: subjects
registered to different templates are not comparable.

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
