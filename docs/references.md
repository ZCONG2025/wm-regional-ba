# References

Everything this pipeline stands on. If you publish work that used it, the
entries under **Method** and **Software** are the ones a methods section should
carry; BibTeX for all of them is at the bottom, ready to paste.

## Method

The pipeline is an assembly of four established ideas.

**Laplace's equation between two boundaries.** Solving Laplace's equation
between an inner and an outer surface, and using its iso-potential level sets as
intermediate surfaces, was introduced for cortical thickness. Here the same
construction runs between the lateral ventricle and the WM/GM boundary, so the
level sets become white-matter surfaces.

> Jones SE, Buchbinder BR, Aharon I. Three-dimensional mapping of cortical
> thickness using Laplace's equation. *Human Brain Mapping*. 2000;11(1):12–32.

**Marching cubes.** Extracts each iso-potential surface from the discrete
potential field (`wmba/marching_cube.py`, via `skimage.measure.marching_cubes`).

> Lorensen WE, Cline HE. Marching cubes: A high resolution 3D surface
> construction algorithm. *ACM SIGGRAPH Computer Graphics*. 1987;21(4):163–169.
> doi:10.1145/37402.37422

**Spherical surface registration and template building.** The two-pass template
procedure and the vertex correspondence it produces are FreeSurfer's, applied to
the mid-surfaces rather than to the cortex (stages 03–06).

> Fischl B, Sereno MI, Tootell RBH, Dale AM. High-resolution intersubject
> averaging and a coordinate system for the cortical surface. *Human Brain
> Mapping*. 1999;8(4):272–284.
> doi:10.1002/(SICI)1097-0193(1999)8:4<272::AID-HBM10>3.0.CO;2-4

**Vox2Cortex.** `wmba/mesh_utils.py` adapts its coordinate-transform and
feature-aggregation utilities. This is also why this repository is GPL-3.0 — see
[`NOTICE`](../NOTICE).

> Bongratz F, Rickmann A-M, Pölsterl S, Wachinger C. Vox2Cortex: Fast explicit
> reconstruction of cortical surfaces from 3D MRI scans with geometric deep
> neural networks. *Proceedings of the IEEE/CVF Conference on Computer Vision
> and Pattern Recognition (CVPR)*. 2022:20773–20783.

## Software

| Used for | Cite |
|---|---|
| `recon-all`, surface inflation, `mris_register`, `mris_make_template`, `mri_surf2surf` | Fischl 2012 |
| FLAIR skull-stripping (`bet`) | Smith 2002 |
| FLAIR-to-T1 registration (`flirt`) | Jenkinson & Smith 2001; Jenkinson et al. 2002 |
| the FSL suite as a whole | Jenkinson et al. 2012 |
| reading/writing FreeSurfer surfaces in Python | Gramfort et al. 2013 (MNE-Python) |
| reading NIfTI and MGZ volumes | NiBabel |
| marching cubes | van der Walt et al. 2014 (scikit-image) |
| Laplace solver, interpolation | Virtanen et al. 2020 (SciPy) |
| array handling throughout | Harris et al. 2020 (NumPy) |
| mesh voxelisation | trimesh |
| vertex-wise volume sampling (`grid_sample`) | Paszke et al. 2019 (PyTorch) |
| DICOM to NIfTI conversion (`tools/`) | Lowekamp et al. 2013 (SimpleITK) |
| optional segmentation stage | Billot et al. 2023 (SynthSeg) |

## Data

If you used ADNI, their Data Use Agreement requires the standard acknowledgement
and the full funding paragraph. Take the current wording from
<https://adni.loni.usc.edu/data-samples/adni-data/> — it is revised periodically,
so do not copy an older paper's version.

## BibTeX

```bibtex
@article{Jones2000Laplace,
  author  = {Jones, Stephen E. and Buchbinder, Bradley R. and Aharon, Itzhak},
  title   = {Three-dimensional mapping of cortical thickness using {Laplace's}
             equation},
  journal = {Human Brain Mapping},
  volume  = {11},
  number  = {1},
  pages   = {12--32},
  year    = {2000}
}

@article{Lorensen1987MarchingCubes,
  author  = {Lorensen, William E. and Cline, Harvey E.},
  title   = {Marching cubes: A high resolution {3D} surface construction
             algorithm},
  journal = {ACM SIGGRAPH Computer Graphics},
  volume  = {21},
  number  = {4},
  pages   = {163--169},
  year    = {1987},
  doi     = {10.1145/37402.37422}
}

@article{Fischl1999Spherical,
  author  = {Fischl, Bruce and Sereno, Martin I. and Tootell, Roger B. H. and
             Dale, Anders M.},
  title   = {High-resolution intersubject averaging and a coordinate system for
             the cortical surface},
  journal = {Human Brain Mapping},
  volume  = {8},
  number  = {4},
  pages   = {272--284},
  year    = {1999},
  doi     = {10.1002/(SICI)1097-0193(1999)8:4<272::AID-HBM10>3.0.CO;2-4}
}

@InProceedings{Bongratz2022Vox2Cortex,
  author    = {Bongratz, Fabian and Rickmann, Anne-Marie and
               P\"olsterl, Sebastian and Wachinger, Christian},
  title     = {Vox2Cortex: Fast Explicit Reconstruction of Cortical Surfaces
               From {3D} {MRI} Scans With Geometric Deep Neural Networks},
  booktitle = {Proceedings of the IEEE/CVF Conference on Computer Vision and
               Pattern Recognition (CVPR)},
  month     = {June},
  year      = {2022},
  pages     = {20773--20783}
}

@article{Fischl2012FreeSurfer,
  author  = {Fischl, Bruce},
  title   = {{FreeSurfer}},
  journal = {NeuroImage},
  volume  = {62},
  number  = {2},
  pages   = {774--781},
  year    = {2012},
  doi     = {10.1016/j.neuroimage.2012.01.021}
}

@article{Jenkinson2012FSL,
  author  = {Jenkinson, Mark and Beckmann, Christian F. and
             Behrens, Timothy E. J. and Woolrich, Mark W. and Smith, Stephen M.},
  title   = {{FSL}},
  journal = {NeuroImage},
  volume  = {62},
  number  = {2},
  pages   = {782--790},
  year    = {2012},
  doi     = {10.1016/j.neuroimage.2011.09.015}
}

@article{Smith2002BET,
  author  = {Smith, Stephen M.},
  title   = {Fast robust automated brain extraction},
  journal = {Human Brain Mapping},
  volume  = {17},
  number  = {3},
  pages   = {143--155},
  year    = {2002},
  doi     = {10.1002/hbm.10062}
}

@article{Jenkinson2001FLIRT,
  author  = {Jenkinson, Mark and Smith, Stephen M.},
  title   = {A global optimisation method for robust affine registration of
             brain images},
  journal = {Medical Image Analysis},
  volume  = {5},
  number  = {2},
  pages   = {143--156},
  year    = {2001},
  doi     = {10.1016/S1361-8415(01)00036-6}
}

@article{Jenkinson2002FLIRT,
  author  = {Jenkinson, Mark and Bannister, Peter and Brady, Michael and
             Smith, Stephen M.},
  title   = {Improved optimization for the robust and accurate linear
             registration and motion correction of brain images},
  journal = {NeuroImage},
  volume  = {17},
  number  = {2},
  pages   = {825--841},
  year    = {2002},
  doi     = {10.1006/nimg.2002.1132}
}

@article{Gramfort2013MNE,
  author  = {Gramfort, Alexandre and Luessi, Martin and Larson, Eric and
             Engemann, Denis A. and Strohmeier, Daniel and Brodbeck, Christian
             and Goj, Roman and Jas, Mainak and Brooks, Teon and
             Parkkonen, Lauri and H\"am\"al\"ainen, Matti},
  title   = {{MEG} and {EEG} data analysis with {MNE-Python}},
  journal = {Frontiers in Neuroscience},
  volume  = {7},
  pages   = {267},
  year    = {2013},
  doi     = {10.3389/fnins.2013.00267}
}

@article{VanDerWalt2014SkImage,
  author  = {van der Walt, St\'efan and Sch\"onberger, Johannes L. and
             Nunez-Iglesias, Juan and Boulogne, Fran\c{c}ois and
             Warner, Joshua D. and Yager, Neil and Gouillart, Emmanuelle and
             Yu, Tony},
  title   = {scikit-image: image processing in {Python}},
  journal = {PeerJ},
  volume  = {2},
  pages   = {e453},
  year    = {2014},
  doi     = {10.7717/peerj.453}
}

@article{Virtanen2020SciPy,
  author  = {Virtanen, Pauli and Gommers, Ralf and Oliphant, Travis E. and
             others},
  title   = {{SciPy} 1.0: fundamental algorithms for scientific computing in
             {Python}},
  journal = {Nature Methods},
  volume  = {17},
  pages   = {261--272},
  year    = {2020},
  doi     = {10.1038/s41592-019-0686-2}
}

@article{Harris2020NumPy,
  author  = {Harris, Charles R. and Millman, K. Jarrod and
             van der Walt, St\'efan J. and others},
  title   = {Array programming with {NumPy}},
  journal = {Nature},
  volume  = {585},
  pages   = {357--362},
  year    = {2020},
  doi     = {10.1038/s41586-020-2649-2}
}

@InProceedings{Paszke2019PyTorch,
  author    = {Paszke, Adam and Gross, Sam and Massa, Francisco and others},
  title     = {{PyTorch}: An Imperative Style, High-Performance Deep Learning
               Library},
  booktitle = {Advances in Neural Information Processing Systems 32 (NeurIPS)},
  year      = {2019},
  pages     = {8024--8035}
}

@article{Lowekamp2013SimpleITK,
  author  = {Lowekamp, Bradley C. and Chen, David T. and Ib\'a\~nez, Luis and
             Blezek, Daniel},
  title   = {The design of {SimpleITK}},
  journal = {Frontiers in Neuroinformatics},
  volume  = {7},
  pages   = {45},
  year    = {2013},
  doi     = {10.3389/fninf.2013.00045}
}

@article{Billot2023SynthSeg,
  author  = {Billot, Benjamin and Greve, Douglas N. and Puonti, Oula and
             Thielscher, Axel and Van Leemput, Koen and Fischl, Bruce and
             Dalca, Adrian V. and Iglesias, Juan Eugenio},
  title   = {{SynthSeg}: Segmentation of brain {MRI} scans of any contrast and
             resolution without retraining},
  journal = {Medical Image Analysis},
  volume  = {86},
  pages   = {102789},
  year    = {2023},
  doi     = {10.1016/j.media.2023.102789}
}

@software{NiBabel,
  author  = {Brett, Matthew and Markiewicz, Christopher J. and
             Hanke, Michael and others},
  title   = {nipy/nibabel},
  url     = {https://nipy.org/nibabel/},
  note    = {Cite the version you used via its Zenodo DOI;
             v5.3.1 is doi:10.5281/zenodo.13936989}
}

@software{Trimesh,
  author = {{Dawson-Haggerty} and others},
  title  = {trimesh},
  url    = {https://trimesh.org/}
}
```

## A note on version numbers

Reviewers increasingly ask which version of each tool you used. The ones this
pipeline was developed against are pinned in
[`requirements.txt`](../requirements.txt) and named in the
[README requirements table](../README.md#requirements) — FreeSurfer 7.1.0 in
particular, since surface outputs are not identical across FreeSurfer major
versions. Record the FreeSurfer version in your methods section.
