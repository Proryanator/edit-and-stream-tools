#!/bin/bash

# list of supported input file formats
inputFormats="mp4|m4v|avi|mov|MOV|wmv|ts|m2ts|mkv|mts"
allFormats="($inputFormats|${inputFormats^^})"

# yeah, this is the only way to invoke the windows ffmpeg command
# otherwise I can't do GPU encoding without some potential weird side-effects
windowsFFMPEG="/mnt/f/Programs/ffmpeg-4.3.2-2021-02-02-essentials_build/bin/ffmpeg.exe"

# keep track of files that might have integrity problems here
hevctoh264log="/mnt/f/Videos/compressionscripts/hevctoh264-log.log"

function log(){
  printf "hevctool@$(date +%R): $1\n"
}

####################### MAIN ########################
if test -z "$1" || test -z "$2"; then
  printf "Usage: hevctoh264 folderToProcess outputDirectory\n"
  printf "\tA tool to almost losslessly encode from h265 to h264\n"
  exit
fi

log "Looking for video containers of: $allFormats..."
inputDirectory=$1
outputDirectory=$2

IFS=$'\n' allMediaFiles=($(find "$inputDirectory" -regextype posix-extended -regex ".*\.$allFormats" -type f))
log "Found ${#allMediaFiles[@]} video files in [$inputDirectory]"

log "Selecting files that are exclusively encoded as hvenc..."
filesToEncode=()

for file in "${allMediaFiles[@]}"
do 
  fileEncoding=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")
  
  if [ "$fileEncoding" = "hevc" ]; then
    filesToEncode+=($file)
  fi
done

filesFiltered=$((${#allMediaFiles[@]}-${#filesToEncode[@]}))
log "Filtered out $filesFiltered file(s) that was already encoded as hevc."

# create error file if it doesn't exist
touch $hevctoh264log

# now begin the actual encoding on each of the files
for file in "${filesToEncode[@]}"
do
  log "Original file: '$file'"
  filename=$(basename -- "$file")
  newFile="${outputDirectory}/${filename}_H264.mp4"
  
  # can we do a more robust way to change the file extension here?
  log "Encoding video to: '$newFile'"
  command="$windowsFFMPEG -y -i '$file' -map 0:v -map 0:a -c:v libx264 -rc constqp -qp 24 -b:v 0K -c:a aac -b:a 384k '$newFile'"
  log "Executing [$command]"
  eval "$command"
  
  # does the file have any data? If no then it failed to be created
  fileSize=$(getBytes "$newFile")
  hevcLog "New file size: $fileSize bytes"
  
  if [ "$fileSize" = "0" ]; then
    hevcLog "Encode must have failed mid way, file was empty: '$newFile'" >> $hevctoh264log
    continue
  fi
  
  # verify the integrity of the newly created video file
  eval "$windowsFFMPEG -v error -i '$newFile' -f null - 2>integrity-error.log"
  anyErrors=$(grep 'error' "integrity-error.log")
  if test -z "$anyErrors"; then
    hevcLog "No integrity issues found with file: '$newFile'"
  else
    hevcLog "Integrity issue found with file: '$newFile'" >> $hevctoh264log
  fi
  
  rm -rf error.log
done
