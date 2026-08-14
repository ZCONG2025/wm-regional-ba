# Known issues

Things found while packaging the code that a user should know about before
trusting the output. Where a defect was fixed in a way that changes results, the
old behaviour is still reachable by flag and the change is called out — see §1.

## 1. The icosphere resampling was rewritten — verified, but not against the old output

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

## 2. Vertices are restricted to white matter, and the original code did not do this

`sampling.py` intended to zero surface vertices falling in subcortical grey
matter. The original code was:

```python
is_BGIT = torch.zeros((40962,))
for roi in BGIT_regions:
    is_BGIT = is_BGIT + (BGIT_sample == roi)
ind_BGIT = is_BGIT.any(dim=0).nonzero()
features[ind_BGIT] = 0
```

`is_BGIT` is 1-D of length 40962, so `.any(dim=0)` reduces it to a **single
scalar**, not a per-vertex mask, and assigning through the resulting index array
selects nothing. **No vertices were ever zeroed.** A second defect compounded it:
the label map was sampled with `mode='nearest'`, but `aggregate_from_indices`
ignored its `mode` argument and always interpolated, so the "labels" it compared
against were numbers naming no structure.

**What this repository does now.** `wmba.sampling` takes `--mask`:

| value | behaviour |
|---|---|
| `wm-only` (**default**) | keep a vertex only if its aseg label is white matter — `2`, `41`, `77` (WM hypointensities), `251`–`255` (corpus callosum), `5001`/`5002`. Zero everything else, cortical and deep grey matter included. |
| `subcortical` | zero only the deep grey structures the original code listed |
| `none` | zero nothing — reproduces the behaviour that produced the published features |

`wm-only` is an **inclusion** list on purpose. An exclusion list silently admits
any label nobody thought to name; an inclusion list cannot. WM hypointensities
(`77`) are deliberately kept — a lesion is still white matter, and lesions are
what this pipeline is built to measure.

The label map is sampled with genuine nearest-neighbour interpolation, which the
original code did not do.

**This changes the features.** Datasets built before this change used no masking
at all. Do not mix `--mask` settings within one analysis, and use `none` if you
are extending results produced by the original code.

## 3. The FLAIR intensity scale is only weakly harmonised

Features are FLAIR intensity divided by the volume maximum
(`flair / torch.max(flair)`). A single bright artifact voxel rescales the whole
volume, and scanner-to-scanner intensity differences survive. This is adequate
when a downstream model regresses within-subject or z-scores per site; it is not
adequate as an absolute intensity measure. Consider a percentile-based
normalisation or white-stripe normalisation if you need cross-site comparability.

## 4. Notes for running under WSL on Windows

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

## 5. The Laplace solver is CPU-bound and slow

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

## 6. Level 0 and level 9 are defined but unused

`LAP_VAL` in `wmba/marching_cube.py` has ten entries; the default
`WMBA_LEVELS` uses 1–8. Level 0 (iso-value 9998.5) sits essentially on the WM
surface and its marching-cubes output is often degenerate; level 9 (3000) runs
into the ventricle. Both are kept for reference but are not recommended.

## 7. `mris_sphere` fails on some subjects

Inflating and spherically parameterising an iso-potential surface is harder than
doing it for a cortical surface: the surfaces can self-intersect after marching
cubes, and `mris_sphere` then fails or takes hours. Expect a small percentage of
scans to drop out at stage 02. `tools/check_completion.py --stage sphere` finds
them. Excluding a failed scan from the template cohort matters more than
excluding it from the analysis cohort — a bad surface in the template degrades
every subsequent registration.
