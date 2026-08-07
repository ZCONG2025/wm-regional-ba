# ---------------------------------------------------------------------------
# WM-RegionalBA -- Python stages only.
#
# What is in here: wmba.masking, wmba.laplacian, wmba.marching_cube,
# wmba.sampling and the tools/ scripts, with their exact dependency versions.
#
# What is NOT in here, and why:
#   FreeSurfer  - redistribution requires their licence; each user registers and
#                 obtains their own license.txt (free for academic use).
#   FSL         - licence prohibits redistribution to commercial users.
#   MATLAB      - proprietary, needs a per-user licence server.
#   SurfStat / mri_surf2ico.sh - third-party code that is not ours to ship.
#
# So this image is a reproducible Python environment, not a one-command
# pipeline. See docs/docker.md for how to combine it with FreeSurfer's own
# official image.
#
#   docker build -t wmba:1.0.0 -f docker/Dockerfile .
#   docker run --rm \
#       -v /path/to/work:/work \
#       -e WMBA_DATA_DIR=/work/data \
#       wmba:1.0.0 \
#       python -m wmba.laplacian --subject SUBJ01 --scan 0 --hemi lh
# ---------------------------------------------------------------------------
FROM python:3.11-slim-bookworm

LABEL org.opencontainers.image.title="WM-RegionalBA" \
      org.opencontainers.image.description="Laplacian white-matter mid-surfaces and FLAIR sampling" \
      org.opencontainers.image.source="https://github.com/ZCONG2025/wm-regional-ba" \
      org.opencontainers.image.licenses="SEE LICENSE IN LICENSE"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    MPLBACKEND=Agg

# trimesh's voxelizer and scikit-image need a C toolchain only at build time.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/wmba

# CPU-only torch: the pipeline never uses a GPU, and this drops ~2 GB.
COPY requirements.txt ./
RUN pip install --extra-index-url https://download.pytorch.org/whl/cpu \
        -r requirements.txt \
    && apt-get purge -y build-essential && apt-get autoremove -y

COPY pyproject.toml README.md LICENSE NOTICE ./
COPY wmba/ ./wmba/
COPY tools/ ./tools/
RUN pip install --no-deps -e .

# Non-root: outputs land in a bind mount, so they must not be owned by root.
RUN useradd --create-home --uid 1000 wmba && mkdir -p /work && chown wmba /work
USER wmba

ENV WMBA_DATA_DIR=/work/data
VOLUME ["/work"]
WORKDIR /work

CMD ["python", "-c", "import wmba; print('wmba', wmba.__version__)"]
