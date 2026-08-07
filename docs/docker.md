# Docker

## What the image gives you, and what it does not

`docker/Dockerfile` builds a reproducible **Python** environment: the four
`wmba` stages, the `tools/` scripts, and their pinned dependencies. That is the
part of the pipeline that is ours to distribute.

The rest is not:

| Component | Why it is not in the image |
|---|---|
| FreeSurfer | Redistribution needs Freesurfer's permission. Each user registers and gets their own `license.txt` (free for academic use). |
| FSL | The FSL licence permits academic use but not redistribution to commercial users. |
| MATLAB | Proprietary; needs a per-user licence server. |
| SurfStat, `mri_surf2ico.sh` | Third-party academic code, not ours to ship. |

So there is no single image that runs the whole pipeline end to end. Do not
promise one in your paper.

## Build and run the Python stages

```bash
docker build -t wmba:1.0.0 -f docker/Dockerfile .
```

```bash
docker run --rm \
  -v /path/to/work:/work \
  -e WMBA_DATA_DIR=/work/data \
  wmba:1.0.0 \
  python -m wmba.laplacian --subject SUBJ01 --scan 0 --hemi lh
```

The container runs as uid 1000. If your host files are owned by a different uid,
add `--user "$(id -u):$(id -g)"`.

## Combining with FreeSurfer's official image

FreeSurfer publishes its own images. Run the FreeSurfer stages there, mounting
your own licence, and the Python stages in `wmba`, against the same working
directory:

```bash
# stage 00, in FreeSurfer's image
docker run --rm \
  -v /path/to/work:/work \
  -v /path/to/license.txt:/opt/freesurfer/license.txt:ro \
  freesurfer/freesurfer:7.1.1 \
  recon-all -sd /work/freesurfer/SUBJ01 -s 0 -i /work/t1/SUBJ01.nii.gz -all

# stages 02a/02b, in this image
docker run --rm -v /path/to/work:/work -e WMBA_DATA_DIR=/work/data \
  wmba:1.0.0 python -m wmba.masking   --subject SUBJ01 --scan 0 --hemi lh
docker run --rm -v /path/to/work:/work -e WMBA_DATA_DIR=/work/data \
  wmba:1.0.0 python -m wmba.laplacian --subject SUBJ01 --scan 0 --hemi lh
```

Never bake `license.txt` into an image you push anywhere — mount it read-only at
run time.

## Why Docker is not code protection

If you are containerising to stop people reading your source, it does not work.
An image is a tarball of layers:

```bash
docker save wmba:1.0.0 -o wmba.tar
tar xf wmba.tar          # every .py file, verbatim
```

`docker cp` from a running container does the same in one command. Anyone who
can run your image has your source. There is no image setting that changes this.

Docker's real value here is that a reviewer can reproduce your numbers three
years from now. That is worth doing on its own merits. For what actually
protects the work, see [`protecting_your_code.md`](protecting_your_code.md).
