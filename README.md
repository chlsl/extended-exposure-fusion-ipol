# Extended Exposure Fusion (EEF)

Octave/Matlab implementation of _Extended Exposure Fusion_, an improved exposure fusion for real bracketed exposure sequences.
Charles Hessel <charles.hessel@cmla.ens-cachan.fr> CMLA, ENS Paris-Saclay

This method is associated to an IPOL publication:
> _Extended Exposure Fusion_, Charles Hessel, In Image Processing On Line 9 (2019) https://www.ipol.im/pub/pre/278/

This method was first described in the following paper:
> HESSEL, Charles, MOREL, Jean-Michel, An Extended Exposure Fusion and its Application to Single Image Contrast Enhancement. In: 2020 IEEE Winter Conference on Applications of Computer Vision (WACV). IEEE, 2020. (to appear)

Version 1.0 released on December, 2019
Future version of this code: https://github.com/chlsl/extended-exposure-fusion-ipol


## Organization

Two fusion methods are included:
1. Extended Exposure Fusion, the method described in the associated IPOL paper. It is implemented in `eef.m`. Use `runeef.m` to run it from the command line.
2. Exposure Fusion, the initial method (implemented by T. Mertens); it is provided for comparison purposes. Call it using `run_ef.m`.

Additionally, the bash script `image_registration.sh` is provided to register a bracketed exposure sequence. Details concerning this program can be found at the end of this file.

The directory is organized as follows:
```bash
├── README.md                               # This README
├── composeHomographies.m               (*) # For the registration
├── eef.m                                   # Main file for EEF method
├── exposureFusion                          # T. Mertens' code, slightly modified
│   ├── LICENSE                         (*)
│   ├── README.md                       (*)
│   ├── downsample.m                    (*)
│   ├── exposure_fusion.m                   # Main file for EF
│   ├── gaussian_pyramid.m              (*)
│   ├── laplacian_pyramid.m             (*)
│   ├── pyramid_filter.m                (*)
│   ├── reconstruct_laplacian_pyramid.m (*)
│   └── upsample.m                      (*)
├── image_registration.sh               (*) # For the registration
├── multiscaleBlendingColor.m               # For the EEF method
├── remapFun.m                              # For the EEF method
├── robustNormalization.m               (*) # For the EEF method
├── run_ef.m                                # Interface with exposureFusion/exposure_fusion.m
└── runeef.m                                # Interface with eef.m
```

`(*)`: not reviewed

**Non-reviewed code**:
- The code in the directory `exposureFusion` is written by Tom Mertens and can be found at https://github.com/Mericam/exposure-fusion (commit `03e2469`). Only the file `exposure_fusion.m` is modified with respect to Tom Mertens' version; a changelog is included in the file itself.

- The scripts `run_ef.m` and `robustNormalization.m` share large parts with the one published in
  > Charles Hessel, An Implementation of the Exposure Fusion Algorithm, Image Processing On Line, 8 (2018), pp. 369–387. https://doi.org/10.5201/ipol.2018.230

- The registration script is strictly identical to the one used in the publication cited above.


## Dependencies

To run this programm, you can use either [GNU Octave](https://www.gnu.org/software/octave/) (version 4.0 or higher) or Matlab (version R2016b or higher).

For Octave, the image package should be first installed. Simply type `pkg install image` in the Octave prompt (or use `eval` as in the example below).
You will also need `gnuplot` and `fig2dev` to print the figure with Octave.
```bash
octave --eval 'pkg install -forge image'
apt-get install gnuplot fig2dev
```


## Usage


### 1. Extended Exposure Fusion

Get help by calling the program `runeef.m` without arguments. It outputs:
```bash
Usage: octave -W -qf runeef.m Beta Wsat Bsat nScales improve image0 image1 [image2 ... imageN]
- Beta: restrained dynamic range in (0,1] (recommended: 0.3)
- Wsat: maximal percentage of white-saturated pixels (recommended: 1)
- Bsat: maximal percentage of black-saturated pixels (recommended: 1)
- nScales: number of scales (recommended: 0). Use
    - n for n scales,
    - 0 for standard depth (as in Mertens et al.),
    - -1 for autoMin (smallest dimension has size 1 in the residual), and
    - -2 for autoMax (largest dimension has size 1 in the residual).
- improve: 1 to use the improved weights, as described in the IPOL paper.
           0 to use the "normal" weights, as described in the WACV paper. (recommended: 1)
- image0: first mandatory image of the sequence
- image1: second mandatory image of the sequence
- image2..imageN: (optional) following images of the sequence.

This script can be run with Matlab too. Please refer to the README file.
```

#### Example

Assuming the input sequence in the directory `test`,
```
octave -W -qf runeef.m 0.3 1 1 0 1 test/*.jpg
```
will apply extended exposure fusion to the provided bracketed sequence and save the result with the name `output_eef.png`. Another file is written; it is a plot of the remapping functions used. Its name is `remapFun.png`. The simulated images and their weights are saved too.

With Matlab, the command is
```
matlab -nodesktop -nodisplay -nosplash -batch "runeef 0.3 1 1 0 1 test/grandcanal_mean.jpg test/grandcanal_over.jpg test/grandcanal_under.jpg"
```

Note: The option "-batch" has been recently introduced in Matlab. If it is not available, use
```bash
matlab -nodesktop -nodisplay -nosplash -r "try, runeef('0.3', '1', '1', '0', '1', 'test/grandcanal_mean.jpg', 'test/grandcanal_over.jpg', 'test/grandcanal_under.jpg'), catch ME, fprintf('Error: %s: %s\n',ME.identifier,ME.message), end, quit"
```

#### Testing

Using the above command, the result `output_eef.png` should be identical to the provided file `test/output_eef_expected.png`.

_Tested with the following configurations: mac os 10.12, Octave 5.1.0; mac os 10.12, Matlab R2018b; Ubuntu 18.04, Octave 4.2.2._


### 2. Exposure Fusion

Get help by calling the program `run_ef.m` without arguments. It outputs:
```
Usage: octave -W -qf run_ef.m Wsat Bsat nScales image0 image1 [image2 ... imageN]
- Wsat: maximal percentage of white-saturated pixels (recommended: 1)
- Bsat: maximal percentage of black-saturated pixels (recommended: 1)
- nScales: number of scales (recommended: 0). Use
    - n for n scales,
    - 0 for standard depth (as in Mertens et al.),
    - -1 for autoMin (smallest dimension has size 1 in the residual), and
    - -2 for autoMax (largest dimension has size 1 in the residual).
- image0: first and mandatory image of the sequence
- image1: second mandatory image of the sequence
- image2..imageN: (optional) following images of the sequence.

This script can be run with Matlab too. Please refer to the README file.
```

#### Example

Assuming an input sequence in the directory `test`,
```
octave -W -qf run_ef.m 1 1 0 test/*.jpg
```
will apply exposure fusion and save the result in `output_ef.png`.
Some other files are written too: the input images, the weights maps and the remapping functions. These supplementary files are used in the online demo.

With Matlab, the command is
```
matlab -nodesktop -nodisplay -nosplash -batch "run_ef 1 1 0 test/grandcanal_mean.jpg test/grandcanal_over.jpg test/grandcanal_under.jpg"
```
If the `-batch` option is not available in your version of Matlab, use `-r` instead. Refer to the previous section for help.

#### Testing

Using the above command, the result `output_ef.png` should be identical to the provided file `test/output_ef_expected.png`.


## Sequence registration

The (optional) script `image_registration.sh` register a series of images on a reference. The reference is the mid-sequence image.
Its code is part of the publication
> Charles Hessel, An Implementation of the Exposure Fusion Algorithm, Image Processing On Line, 8 (2018), pp. 369–387. https://doi.org/10.5201/ipol.2018.230

and has been reviewed in this context. Please refer to this paper for details.

The following steps are applied.
First, to pairs of consecutive images in the sequence:
  1. midway image equalization (give the two images the same histogram);
  2. estimation of the homography.
Then, pairing all images with the reference one:
  3. computation of the homography for non-adjacent images (by composition of
     the previously estimated homographies);
  4. interpolation of the registered image.


### Prerequisites and installation instructions

We report below a condensed recap of the prerequisite and build instructions of the three program called by the registration script.  More information can be found in the readme files of the respective source code.

Required environment: Any unix-like system with a standard compilation environment (make, C compiler and C++ compiler)

Required libraries:
- libpng and gnuplot for midway
- in addition: lipjpeg, libtiff for homography
- in addition: (optional) gsl for bspline interpolation.

#### 1) Midway Image Equalization
[Midway Image Equalization](http://www.ipol.im/pub/art/2016/140) (Thierry Guillemot, and Julie Delon, Implementation of the Midway Image Equalization, Image Processing On Line, 6 (2016), pp. 114–129. <https://doi.org/10.5201/ipol.2016.140>)
```bash
wget http://www.ipol.im/pub/art/2016/140/midway.zip
unzip midway.zip
(cd src_ipol && make)
```

#### 2) Homography estimation
[Homography estimation](https://www.ipol.im/pub/art/2018/222/) (Thibaud Briand, Gabriele Facciolo, and Javier Sánchez, Improvements of the Inverse Compositional Algorithm for Parametric Motion Estimation, Image Processing On Line, 8 (2018), pp. 435–464. <https://doi.org/10.5201/ipol.2018.222>).
Tested with the [Github version](https://github.com/tbriand/modified_inverse_compositional/) at commit 01ffa47.
```bash
wget https://github.com/tbriand/modified_inverse_compositional/archive/master.zip
unzip master.zip
(cd modified_inverse_compositional-master && make)
```

#### 3) Bspline interpolation
[Bspline interpolation](http://www.ipol.im/pub/art/2018/221/) (Thibaud Briand, and Pascal Monasse, Theory and Practice of Image B-Spline Interpolation, Image Processing On Line, 8 (2018), pp. 99–141. <https://doi.org/10.5201/ipol.2018.221>)
```bash
wget http://www.ipol.im/pub/art/2018/221/bspline_1.00.zip
unzip bspline_1.00.zip
(cd bspline_1.00 && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release ../src && \
    make)
```

#### 4) Move the binaries in the same directory as "image_registration.sh"
```bash
mv src_ipol/bin/midway \
    modified_inverse_compositional-master/inverse_compositional_algorithm \
    bspline_1.00/build/bspline .
```

#### To use Matlab instead of Octave
The script uses Octave for multiplying matrices.
To use Matlab instead, you will have to modify both `composeHomographies.m` and
`image_registration.sh`. In composeHomographies.m, replace the first line by
```matlab
function composeHomographies (f_B2A, f_C2B, f_C2A)
```
then in `image_registration.sh`, uncomment
```bash
COMPOSE="matlab_compose"
function matlab_compose {
  matlab -nodesktop -nojvm -r "composeHomographies('$1','$2','$3'); quit"
}
```
from line 10 to line 13 (and comment line 9).
Remember that matlab must be in your path.


### Usage

Add the current directory to the search path so that the executables can be found by the script:
```bash
export PATH=$PATH:$(pwd)
```
Then, simply run
```bash
./image_registration.sh image1 image2 ... imageN
```
This registers the N images on image number (floor(N/2)). The output images have "registered" appended to their file name.


### Example

Assuming a directory "house" copied inside "src" and containing the images "A.jpg", "B.jpg", "C.jpg" and "D.jpg" sorted by exposure time. Register with:
```bash
./image_registration.sh house/A.jpg house/B.jpg house/C.jpg house/D.jpg
```


## Known issues

For Ubuntu users, if `sudo apt install fig2dev` complains about not being able to locate `fig2dev`, try installing `transfig` instead.

