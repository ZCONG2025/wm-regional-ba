"""WM-RegionalBA: Laplacian white-matter mid-surfaces and FLAIR sampling.

Modules are runnable:

    python -m wmba.masking       --subject S --session 0 --hemi lh
    python -m wmba.laplacian     --subject S --session 0 --hemi lh
    python -m wmba.marching_cube --subject S --session 0 --hemi lh --level 4
    python -m wmba.sampling      --subject S --session 0 --hemi lh --level 4 --flair I123456
"""

__version__ = "1.0.0"
