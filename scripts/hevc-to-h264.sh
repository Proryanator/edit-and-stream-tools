#!/bin/bash

# import mostly shared methods from the shared file
. $(pwd)/ffmpegutils.sh

logPrefix="hevc-to-h264"

########################### MAIN ####################################

if test -z "$1"; then
  printf "Usage: hevc-to-h264 folderToProcess outputLocation originals\n"
  printf "A tool to transcode HEVC video to H264 for programs that don't support HEVC\n"
  exit
fi

getFilesToEncode "$1" "$2" "$3"
filterFilesToEncode "$HEVC_ENCODING"
processFiles "$H264_ENCODING"