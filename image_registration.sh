#!/bin/bash
set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Executable paths
MIDWAY="midway"
MOTIONESTIM="inverse_compositional_algorithm"
INTERP="bspline"
COMPOSE="octave $DIR/composeHomographies.m"
# COMPOSE="matlab_compose"
# function matlab_compose {
#   matlab -nodesktop -nojvm -r "composeHomographies('$1','$2','$3'); quit"
# } # Make sure "composeHomographies.m" is in the current directory.

if [ $# -lt 2 ];
then
  echo "Incorrect number of parameters."
  echo "Usage: $0 image0 image1 [image2 image3 ... imageN]"
  echo ""
  echo "Images are registered on the mid-sequence one."
  echo "To help the registration, sort the inputs by exposure time to"
  echo "minimize the intensity difference between consecutive images."
  exit 1
fi

NIM=$#               # number of images
SEQ=( "$@" )         # input sequence
REF=$(( (NIM-1)/2 )) # index of reference image

echo "=== Registration of $NIM images, using as reference ${SEQ[$REF]}"
echo "  * Midway histogram specification"
echo "  * Estimation of the homography"
echo "  * Interpolation"

for (( n = 0; n < NIM; n++ )); do     # Convert images to png
  {
    echo "convert ${SEQ[$n]} to png" >&2
    convert "${SEQ[$n]}" converted_"$n".png
    if [ -f converted_"$n"-1.png ];   # for tif images with thumbnail
    then
      rm converted_"$n"-1.png         # this is the thumbnail
      mv converted_"$n"-0.png converted_"$n".png
    fi
  } &
done
wait

for (( n = 0; n < NIM; n++ )); do # Compute homographies using pairs of images
  {
    if [ $n -lt $REF ]; then
      echo "Estimate homography from $n to $(( n+1 )) (forward)" >&2
      $MIDWAY "converted_"$n".png" \
              "converted_"$(( n+1 ))".png" \
              "midway_"$n"-with-"$(( n+1 ))".png" \
              "midway_"$(( n+1 ))"-with-"$n".png"

      $MOTIONESTIM "midway_"$n"-with-"$(( n+1 ))".png" \
                   "midway_"$(( n+1 ))"-with-"$n".png" \
                   -o 1 -f "transform_"$n"-to-"$(( n+1 ))".mat"
    elif [ $n -eq $REF ]; then
      continue
    else
      echo "Estimate homography from $n to $(( n-1 )) (backward)" >&2
      $MIDWAY "converted_"$n".png" \
              "converted_"$(( n-1 ))".png" \
              "midway_"$n"-with-"$(( n-1 ))".png" \
              "midway_"$(( n-1 ))"-with-"$n".png"

      $MOTIONESTIM "midway_"$n"-with-"$(( n-1 ))".png" \
                   "midway_"$(( n-1 ))"-with-"$n".png" \
                   -o 1 -f "transform_"$n"-to-"$(( n-1 ))".mat"
    fi
  } &
done
wait

{ # Compute homographies by composing them (going backward)
  if [ $REF -gt 1 ]; then
    for (( n = $(( REF - 2 )); n >= 0; n-- )); do
      echo "Compute homography from $n to $REF" >&2
      $COMPOSE transform_"$(( n+1 ))"-to-"$REF".mat \
               transform_"$n"-to-"$(( n+1 ))".mat \
               transform_"$n"-to-"$REF".mat
    done
  fi
} &
{ # Compute homographies by composing them (going forward)
  if [ $(( NIM-REF )) -gt 2 ]; then
    for (( n = $(( REF + 2 )); n <= $(( NIM-1 )); n++ )); do
      echo "Compute homography from $n to $REF" >&2
      $COMPOSE transform_"$(( n-1 ))"-to-"$REF".mat \
               transform_"$n"-to-"$(( n-1 ))".mat \
               transform_"$n"-to-"$REF".mat
    done
  fi
} &
wait

for (( n = 0; n < NIM; n++ )); do # Interpolate the images
  {
    REG=$(basename "${SEQ[$n]}")
    REG="${REG%.*}"
    REG="${REG// /_}" # replace whitespace by underscore
    REG="$REG"_registered.png
    if [ $n -eq $REF ]; then
      cp converted_"$REF".png "$REG"
      continue
    fi
    echo "Interpolate ${SEQ[$n]}" >&2
    $INTERP "$(cat transform_"$n"-to-"$REF".mat)" converted_"$n".png "$REG" 5
  } &
done
wait

rm -f converted_*.png
rm -f midway_*-with-*.png
rm -f transform_*-to-*.mat

