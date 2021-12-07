#!/bin/bash

# import mostly shared methods from the shared file
. $(pwd)/ffmpegutils.sh

logPrefix="hevctool"

########################### MAIN ####################################

if test -z "$1"; then
  printf "Usage: hevctools folderToProcess outputLocation originals -d\n"
  printf "A tool to compress all the videos found in the folder to H265/HEVC\n"
  printf "\t -d delete the newly generated file if it's larger than the original\n"
  exit
fi

getFilesToEncode "$1" "$2" "$3"
filterFilesToEncode "$H264_ENCODING"
processFiles "$HEVC_ENCODING"