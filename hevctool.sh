#!/bin/bash

# list of supported input file formats
inputFormats="mp4|m4v|avi|mov|MOV|wmv|ts|m2ts|mkv|mts"
allFormats="($inputFormats|${inputFormats^^})"

# yeah, this is the only way to invoke the windows ffmpeg command
# otherwise I can't do GPU encoding without some potential weird side-effects
windowsFFMPEG="/mnt/f/Programs/ffmpeg-4.3.2-2021-02-02-essentials_build/bin/ffmpeg.exe"

# keep track of files that might have integrity problems here
fileErrors="/mnt/f/Videos/compressionscripts/hevctool-log.log"

directoryToDeleteStuff="/mnt/f/Videos/compressionscripts/hevc_deletion_pile"

function hevcLog(){
  printf "hevctool@$(date +%R): $1\n"
}

function getBytes(){
  echo $(wc -c "$1" | awk '{print $1}')
}

########################### MAIN ####################################

if test -z "$1"; then
  printf "Usage: hevctools folderToProcess [-m]\n"
  printf "A tool to compress all the videos found in the folder to H265/HEVC\n"
  printf "\t-m\tMoves the original file to $directoryToDeleteStuff if no errors were found in the resulting file.\n"
  exit
fi

hevcLog "Looking for video containers of: $allFormats..."
inputDirectory=$1

IFS=$'\n' allMediaFiles=($(find "$inputDirectory" -regextype posix-extended -regex ".*\.$allFormats" -type f))
hevcLog "Found ${#allMediaFiles[@]} video files in [$inputDirectory]"

hevcLog "Filtering out files that are already hevc encoded..."
filesToEncode=()

for file in "${allMediaFiles[@]}"
do 
  fileEncoding=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")
  
  if [ "$fileEncoding" != "hevc" ]; then
    filesToEncode+=($file)
  fi
done

filesFiltered=$((${#allMediaFiles[@]}-${#filesToEncode[@]}))
hevcLog "Filtered out $filesFiltered file(s) that was already encoded as hevc."

# create error file if it doesn't exist
touch $fileErrors

# now begin the actual encoding on each of the files
for file in "${filesToEncode[@]}"
do
  # keeping track of the original file size. If it's smaller than the re-encoded version, delete the new file
  originalFileSize=$(getBytes "$file")
  
  hevcLog "Original file: '$file'"
  hevcLog "Original file size: $originalFileSize bytes"
  newFile="${file}_HEVC.mp4"
  
  # can we do a more robust way to change the file extension here?
  hevcLog "Encoding video to: '$newFile'"
  command="$windowsFFMPEG -y -hwaccel auto -i '$file' -map 0:v -map 0:a -c:v hevc_nvenc -rc constqp -qp 24 -b:v 0K -c:a aac -b:a 384k '$newFile'"
  hevcLog "Executing [$command]"
  eval "$command"
  
  # does the file have any data? If no then it failed to be created
  fileSize=$(getBytes "$newFile")
  hevcLog "New file size: $fileSize bytes"
  
  if [ "$fileSize" = "0" ]; then
    hevcLog "Encode must have failed mid way, file was empty: '$newFile'" >> $fileErrors
    continue
  fi
  
  # was the file size of the new file larger?
  if [ "$originalFileSize" \< "$fileSize" ]; then
    hevcLog "New file size was actually larger than the original, deleting the new file $newFile" >> $fileErrors
    rm -rf "$newFile"
    continue
  fi
  
  # verify the integrity of the newly created video file
  eval "$windowsFFMPEG -v error -i '$newFile' -f null - 2>integrity-error.log"
  anyErrors=$(grep 'error' "integrity-error.log")
  if test -z "$anyErrors"; then
    hevcLog "No integrity issues found with file: '$newFile'"
    
    # if you so choose, you can delete the original file now
    if test -z "$2"; then
      hevcLog "Keeping the original file."
    else
      hevcLog "Moving file '$file' into folder pending deletion: [$directoryToDeleteStuff]"
      mkdir -p "$directoryToDeleteStuff"
      filename=$(basename -- "$file")
      mv "$file" "$directoryToDeleteStuff/$filename"
    fi
  else
    hevcLog "Integrity issue found with file: '$newFile'" >> $fileErrors
  fi
  
  rm -rf error.log
done