# Known issues

## 0. The icosphere resampling was rewritten — verified, but not against the old output

Stage 06 used to resample surfaces through a MATLAB function that depended on an
in-house toolbox. It is now a single `mri_surf2surf` call.

**Verified end to end** on ADNI 002_S_4213 (lh, level 4) with FreeSurfer 7.4.1:

| check | result |
|---|---|
| all eight flags exist in 7.4.1 | yes, semantics as documented |
| `ico` target resolves without an `ico` subject dir | yes — reads `$FREESURFER_HOME/lib/bem/ic6.tri` |
| vertices / faces out | 40 962 / 81 920 |
| source vertices lost | `nSrcLost = 0` |
| enclosed volume, source → resampled | 113.2 cm³ → 113.2 cm³ |

The volume being unchanged is the meaningful one: resampling changed the vertex
sampling and topology without distorting the geometry, which is exactly its job.

**Still unverified:** agreement with the *old MATLAB path*, vertex for vertex. No
dataset processed the old way was available to compare against. If you have one,
this is worth five minutes:

```python
import numpy as np, scipy.io, mne
new, _ = mne.read_surface(".../midsurf/lvl4/lh_lvl4_ico_6")
old = scipy.io.loadmat(".../midsurf/lvl4/lh_coord.mat")["coord"]
print(new.shape, old.shape, np.abs(new - old).max())   # expect (40962,3) twice, ~0
```

Both paths resample the same coordinates through the same registration onto the
same icosahedron, so they should agree to floating-point noise. Please open an
issue if they do not.

Old datasets are unaffected either way: `wmba.sampling` still reads
`<hemi>_coord.mat` when the new surface file is absent.

Things found while packaging the code that a user should know about before
trusting the output. Nothing here was silently changed: where behaviour is in
question, the original behaviour is still the default.

## 1. Subcortical ("BGIT") masking never took effect

`sampling.py` intended to zero out surface vertices that fall inside subcortical
structures (thalamus, caudate, putamen, pallidum, accumbens, lateral ventricle,
choroid plexus, hippocampus). The original code was:

```python
is_BGIT = torch.zeros((40962,))
for roi in BGIT_regions:
    is_BGIT = is_BGIT + (BGIT_sample == roi)
ind_BGIT = is_BGIT.any(dim=0).nonzero()
features[ind_BGIT] = 0
```

`is_BGIT` is 1-D of length 40962, so `.any(dim=0)` reduces it to a **single
scalar**, not a per-vertex mask. `.nonzero()` on a 0-dim tensor yields an index
array of shape `(n, 0)`, and assigning through it selects nothing. **No vertices
were ever zeroed.**

A second problem compounded it: the label map was sampled with
`sampling(..., 'nearest')`, but `aggregate_from_indices` ignored its `mode`
argument and always used bilinear interpolation. Interpolating integer aseg
labels produces values that match no label, so even a correct index expression
would have matched almost nothing.

**What this repository does.** `wmba.sampling` takes `--bgit-mask`:

- `legacy` (**default**) — no vertices are excluded. This reproduces the
  behaviour that produced the published features.
- `fixed` — samples the aseg with genuine nearest-neighbour interpolation and
  zeroes vertices whose label is in `BGIT_REGIONS`.

If you are extending previously computed results, keep `legacy` so old and new
features remain comparable. If you are starting a new analysis, `fixed` is what
the code was meant to do. Do not mix the two within one dataset.

## 2. The FLAIR intensity scale is only weakly harmonised

Features are FLAIR intensity divided by the volume maximum
(`flair / torch.max(flair)`). A single bright artifact voxel rescales the whole
volume, and scanner-to-scanner intensity differences survive. This is adequate
when a downstream model regresses within-subject or z-scores per site; it is not
adequate as an absolute intensity measure. Consider a percentile-based
normalisation or white-stripe normalisation if you need cross-site comparability.

## 2b. Notes for running under WSL on Windows

FreeSurfer needs Linux; on Windows that means WSL. A few things cost time to
discover:

- **WSL1 is the better choice here, not a fallback.** WSL2 needs hardware
  virtualisation (unavailable on some machines, including Boot Camp Macs where
  the EFI exposes no toggle) and its `/mnt/c` I/O is slow. WSL1 needs no
  virtualisation and accesses Windows files at native speed — and this pipeline's
  inputs usually live on the Windows side. Set `wsl --set-default-version 1`
  *before* registering a distribution.
- **Ubuntu 24.04 renamed packages.** The 64-bit `time_t` transition means
  `libxt6` is now `libxt6t64`, and FreeSurfer's official `.deb` is built for
  Ubuntu 22, so its declared dependencies may not resolve. If `apt-get install
  ./freesurfer_*.deb` refuses, `dpkg -x` the archive instead — FreeSurfer's
  binaries are largely self-contained.
- **Background jobs die when the WSL session ends.** `nohup ... &` inside a
  `wsl.exe -e bash -c` call is killed when that call returns, because WSL tears
  the distribution down once its last process exits. Keep the `wsl.exe` process
  itself in the foreground for the duration of any long job.
- **Prefer downloading to `/mnt/c`.** Files there survive a distribution reset
  and are visible from both sides.
- **`OMP: Error #15`** on conda Python: conda's MKL and pip's torch each ship an
  OpenMP runtime. `KMP_DUPLICATE_LIB_OK=TRUE` alone is documented as unsafe;
  pair it with `OMP_NUM_THREADS=1` so the two runtimes cannot contend for
  threads. Linux installs do not hit this.

## 3. `surf/` is used as a shared scratch directory

Several stages copy a level's files into `<scan>/surf/`, run a FreeSurfer tool
(which only reads from `surf/`), then move everything back into
`<scan>/midsurf/lvl<N>/`. Consequences:

- **Two levels of the same scan must not run concurrently.** They will clobber
  each other's `surf/` contents. Parallelise across subjects, never across
  levels within a subject.
- If a stage dies midway, `surf/` can be left holding another level's files.
  `bin/run_subject.sh` is resume-safe against missing outputs, but not against
  this. When a scan behaves strangely, delete `<scan>/surf/` and
  `<scan>/midsurf/` and rerun that scan from stage 02.

## 4. The Laplace solver is CPU-bound and slow

`wmba.laplacian` does Jacobi sweeps over a conformed 256³ volume with
`scipy.ndimage.convolve`, and dominates the runtime of everything after
`recon-all`.

Measured end to end on one subject (ADNI 002_S_4213, one core of an i5-4308U):

| | lh | rh |
|---|---|---|
| sweeps to converge | 1711 | 1728 |
| final residual | 4.98e-07 | 4.97e-07 |
| wall clock | 34 min 43 s | 34 min 59 s |

So ~1.2 s per sweep and **~35 min per hemisphere**. It converges well inside the
10000-sweep cap, so the cap is a backstop, not the expected exit. Convergence is
not linear — the residual falls from ~1e3 at sweep 20 to 8.5e-02 at 500 and
5e-04 at 1000 — so do not extrapolate the runtime from the first few sweeps.

`scipy.ndimage.convolve` is single-threaded, so extra cores do not speed up one
hemisphere. The two hemispheres share no scratch at this stage and were verified
to run side by side at full speed.

A multigrid or conjugate-gradient solver would still be far faster, and is the
obvious place to optimise if this ever becomes the bottleneck for a large cohort.

## 5. Level 0 and level 9 are defined but unused

`LAP_VAL` in `wmba/marching_cube.py` has ten entries; the default
`WMBA_LEVELS` uses 1–8. Level 0 (iso-value 9998.5) sits essentially on the WM
surface and its marching-cubes output is often degenerate; level 9 (3000) runs
into the ventricle. Both are kept for reference but are not recommended.

## 6. `mris_sphere` fails on some subjects

Inflating and spherically parameterising an iso-potential surface is harder than
doing it for a cortical surface: the surfaces can self-intersect after marching
cubes, and `mris_sphere` then fails or takes hours. Expect a small percentage of
scans to drop out at stage 02. `tools/check_completion.py --stage sphere` finds
them. Excluding a failed scan from the template cohort matters more than
excluding it from the analysis cohort — a bad surface in the template degrades
every subsequent registration.
