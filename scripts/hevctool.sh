#!/bin/bash

# list of supported input file formats
inputFormats="mp4|m4v|avi|mov|MOV|wmv|ts|m2ts|mkv|mts"
allFormats="($inputFormats|${inputFormats^^})"

# keep track of files that might have integrity problems here
fileErrors="hevctool-log.log"

function hevcLog(){
  printf "hevctool@$(date +%R): $1\n"
}

function getBytes(){
  echo $(wc -c "$1" | awk '{print $1}')
}

########################### MAIN ####################################

if test -z "$1"; then
  printf "Usage: hevctools folderToProcess outputLocation originals -d\n"
  printf "A tool to compress all the videos found in the folder to H265/HEVC\n"
  prinft "-d\tdelete the newly generated file if it's larger than the original"
  exit
fi

hevcLog "Looking for video containers of: $allFormats..."
inputDirectory=$1
outputDirectory=$2
originalsDirectory=$3

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
  # command="ffmpeg -y -hwaccel auto -i '$file' -map 0:v -map 0:a -c:v hevc_nvenc -rc constqp -qp 24 -b:v 0K -c:a aac -b:a 384k '$newFile'"
  command="ffmpeg -y -i '$file' -c:v libx265 -vtag hvc1 '$newFile'"
  hevcLog "Executing [$command]"
  eval "$command"
  
  # does the file have any data? If no then it failed to be created
  fileSize=$(getBytes "$newFile")
  hevcLog "New file size: $fileSize bytes"
  
  if [ "$fileSize" = "0" ]; then
    hevcLog "Encode must have failed mid way, file was empty: '$newFile'" >> $fileErrors
    continue
  fi

  if test -z "$4"; then
    hevcLog "Ignoring newly encoded file size."
  else
    # was the file size of the new file larger?
    if [ "$originalFileSize" \< "$fileSize" ]; then
      hevcLog "New file size was actually larger than the original, deleting the new file $newFile" >> $fileErrors
      rm -rf "$newFile"
      continue
    fi
  fi
  
  # verify the integrity of the newly created video file
  eval "ffmpeg -v error -i '$newFile' -f null - 2>integrity-error.log"
  anyErrors=$(grep 'error' "integrity-error.log")
  if test -z "$anyErrors"; then
    hevcLog "No integrity issues found with file: '$newFile'"
  else
    hevcLog "Integrity issue found with file: '$newFile'" >> $fileErrors
  fi

  # move original to avoid re-encoding
  hevcLog "Moving file '$file' into folder pending deletion: [$originalsDirectory]"
  mkdir -p "$originalsDirectory"
  filename=$(basename -- "$file")
  mv "$file" "$originalsDirectory/$filename"

  # finally move the finished encoded product to the outputs directory
  hevcLog "Moving finished file '$newFile' to output directory: [$outputDirectory]"
  mv "$newFile" "$outputDirectory/$filename"
  
  rm -rf error.log
done