# WM-RegionalBA

Vertex-wise white-matter features for regional brain-age modelling.

Cortical brain-age models sample features on the cortical surface. The white
matter has no such surface — it is a solid volume. This pipeline builds one:
it solves the Laplace equation between the lateral ventricle and the WM/GM
boundary, extracts eight nested iso-potential surfaces from that field, and puts
them all into vertex-wise correspondence across subjects using FreeSurfer's
spherical registration. FLAIR intensity sampled on those surfaces is the feature
vector.

Output per scan: 8 levels × 2 hemispheres × 40962 vertices, where vertex *i* at
level *l* is the same white-matter location in every subject.

![Eight nested iso-potential surfaces between the lateral ventricle and the WM/GM boundary, resampled onto a common icosphere](docs/figures/midsurfaces.svg)

## Requirements

Installed and licensed by you — none of these are redistributed here:

| | version used | needed for |
|---|---|---|
| [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/) | 7.1.0 | recon-all, surface inflation, spherical registration |
| [FSL](https://fsl.fmrib.ox.ac.uk/fsl/) | 6.x | FLAIR skull-strip and co-registration (`bet`, `flirt`) |
| MATLAB | R2020b+ | icosphere resampling |
| [SurfStat](https://math.mcgill.ca/keith/surfstat/) + FreeSurfer MATLAB utilities | — | reading/writing surfaces in MATLAB |
| Python | 3.9+ | the `wmba` package |

FreeSurfer needs a licence file (free, academic). Get one at
<https://surfer.nmr.mgh.harvard.edu/registration.html>.

## Install

```bash
git clone https://github.com/ZCONG2025/wm-regional-ba.git
cd wm-regional-ba

conda env create -f environment.yml && conda activate wmba
# or: pip install -e .

cp config/config.example.sh config/config.sh
$EDITOR config/config.sh          # point it at FreeSurfer, FSL, MATLAB, your data
```

`config/config.sh` is git-ignored, so your paths stay on your machine. Every
setting can also be overridden by exporting the variable before running.

## Run

### What you need per scan

Two NIfTI images of the same person at the same session:

```
$WMBA_T1_DIR/I123455.nii.gz        T1-weighted, whole head, not skull-stripped
$WMBA_FLAIR_DIR/I123456.nii.gz     FLAIR, same session
```

The basenames are the "image ids" you pass on the command line. Any naming
scheme works; the pipeline only needs the two files to exist where
`config/config.sh` points.

### One subject

```bash
bin/run_subject.sh SUBJ01 "$WMBA_T1_DIR/I123455.nii.gz" I123456 0
```

Arguments: subject id, T1 file, FLAIR image id, scan/session id.

That one command runs the whole chain — FreeSurfer `recon-all`, the Laplace
solve, eight iso-surfaces per hemisphere, spherical registration to the
template, icosphere resampling, FLAIR sampling. Steps whose output already
exists are skipped, so rerunning after a failure resumes rather than restarts.

**It is slow.** Roughly 8–14 h for `recon-all`, 10–40 min per hemisphere for the
Laplace solve, and 5–20 min per level per hemisphere for the registration — on
the order of a day per scan on one core. This is a cluster pipeline.

### What lands on disk

```
$WMBA_DATA_DIR/SUBJ01/0/
├── aseg.mgz  brain.mgz  lh.white  rh.white     staged from FreeSurfer
├── T1.nii.gz                                   conformed, skull-stripped
├── I123456_FLAIR_converted.nii.gz              FLAIR aligned to the T1
├── mask/
│   ├── lap_mask_lh.nii                         Laplace domain  (1 / 2 / 3)
│   └── lap_lh.nii                              potential field (0 .. 10000)
└── midsurf/
    ├── lvl1/
    │   ├── lh.sphere  lh.sphere.reg1           spherical registration
    │   ├── lh_lvl1_ico_6.obj                   surface on the icosphere
    │   ├── lh_coord.mat                        its vertex coordinates
    │   ├── I123456_lh.txt   ◄── THE OUTPUT     40962 FLAIR intensities
    │   └── I123456_rh.txt   ◄── THE OUTPUT
    ├── lvl2/  ...
    └── lvl8/  ...
```

Everything except those `.txt` files is intermediate. **The result is 16 text
files per scan** (8 levels × 2 hemispheres), one float per line, 40962 lines
each.

### Loading the result

```python
import numpy as np

def load_scan(data_dir, subject, scan, flair_id, levels=range(1, 9)):
    """-> (8, 2, 40962) array indexed by level, hemisphere, vertex."""
    return np.array([
        [np.loadtxt(f"{data_dir}/{subject}/{scan}/midsurf/lvl{lv}/{flair_id}_{h}.txt")
         for h in ("lh", "rh")]
        for lv in levels
    ])

x = load_scan("/work/data", "SUBJ01", "0", "I123456")
x.shape        # (8, 2, 40962)
x.reshape(-1)  # 655392-element feature vector for this scan
```

Vertex *i* at level *l* is the same white-matter location in every subject, so a
cohort stacks straight into an `(n_subjects, 655392)` matrix. Feed that to
whatever brain-age model you like — **this repository produces the features, it
does not fit the model.**

### A cohort on an SGE cluster

One line per scan, `<subject> <t1_id> <flair_id> [scan]`:

```
SUBJ01  I123455  I123456  0
SUBJ02  I223455  I223456  0
```

```bash
python cluster/make_array_job.py subjects.tsv jobs/cohort.arr
cluster/submit_array.sh jobs/cohort.arr 300 50     # 300 tasks, 50 at a time
```

Parallelise across subjects only, never across levels within one subject — see
[`docs/known_issues.md`](docs/known_issues.md) §3.

### Checking progress

```bash
python tools/check_completion.py --stage feature --flair-id I123456
```

Prints every incomplete scan and exits non-zero if anything is missing, so it
works as a gate in a script. `--stage sphere` and `--stage obj` check the
earlier stages, which is where failures actually happen.

### Building a template from scratch

**Most users never do this.** You need it only if you have no
`$WMBA_TEMPLATE_DIR/?hlvl?_1.tif` — the surface templates every subject is
registered to. It is a one-off job over a few hundred subjects; the procedure is
in [`docs/pipeline.md`](docs/pipeline.md).

## Documentation

| | |
|---|---|
| [`docs/pipeline.md`](docs/pipeline.md) | what each stage does, how to build a template, output format |
| [`docs/known_issues.md`](docs/known_issues.md) | **read before trusting the output** — behaviour that differs from what the code appears to intend |
| [`docs/docker.md`](docs/docker.md) | containerised Python stages, and why the full pipeline cannot be one image |
| [`docs/FILE_MAP.md`](docs/FILE_MAP.md) | how this repository maps onto the original research scripts |

## Data

No subject data is included. This pipeline was developed on
[ADNI](https://adni.loni.usc.edu/), whose Data Use Agreement prohibits
redistributing subject-level data — including id lists, scan dates and clinical
variables, not only images. Apply for access directly. `.gitignore` blocks the
relevant file types so they cannot be committed by accident.

## Citing

If this pipeline contributes to work you publish, please cite it — see
[`CITATION.cff`](CITATION.cff) (GitHub renders a "Cite this repository" button).

## Licence

**GPL-3.0-only** — see [`LICENSE`](LICENSE). You may use, modify and
redistribute this code, but anything you distribute that builds on it must also
be released under the GPL-3.0.

This is inherited, not chosen: `wmba/mesh_utils.py` adapts coordinate-transform
and feature-aggregation code from [Vox2Cortex](https://github.com/ai-med/Vox2Cortex),
which is GPL-3.0. [`NOTICE`](NOTICE) lists exactly which functions and how they
were modified.

The licence covers the code in this repository only. FreeSurfer, FSL, MATLAB,
SurfStat and SynthSeg each carry their own licence and must be obtained
separately.
