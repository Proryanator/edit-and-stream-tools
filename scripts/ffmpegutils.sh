#!/bin/bash

# list of supported input file formats
inputFormats="mp4|m4v|avi|mov|wmv|ts|m2ts|mkv|mts"
allFormats="($inputFormats|$(echo "$inputFormats" | tr '[a-z]' '[A-Z]'))"

logPrefix="NoPrefixSet"

# locations of where to process/store files
inputDirectory=""
outputDirectory=""
originalsDirectory=""

# array of all media files to process
allMediaFiles=()

# filtered list of files to encode
filesToEncode=()

# stores any error encountered in this errors file
fileErrors="$outputDirectory/errors.log"
tmpErrorsFile="$outputDirectory/integrity.log"

# pre-defined supported encoding formats
H264_ENCODING="h264"
HEVC_ENCODING="hevc"

# arguments to convert TO the specified format
HEVC_ARGS="-y -hwaccel auto -map 0:v -map 0:a -c:v hevc_nvenc -rc constqp -qp 24 -b:v 0K -c:a aac -b:a 384k"
H264_ARGS="-y -hwaccel auto -map 0:v -map 0:a -c:v h264_nvenc -rc constqp -qp 16 -b:v 0K -c:a aac -b:a 384k"

# my url https://discord.com/api/webhooks/917858116434022420/nM_BwM-b9XiucTntf6uww22dsZlmB4LvWLOLNywR14aWD0wvLNLtBgYwoieoI5ceRslk

# pre-defined DISCORD messages
DISCORD_ERRORS="Errors were encountered during the last encoding session, please check the logs for more information."
DISCORD_SUCCESS="Successfully encoded input files."

# uses a pre-defined prefix for the log prefix
function log(){
  printf "%s@%s: %s\n" "$logPrefix" $(date +%R) "$1"
}

function getBytes(){
  wc -c "$1" | awk '{print $1}'
}

function getFilesToEncode(){
  log "Looking for video containers of: $allFormats..."
  inputDirectory=$1
  outputDirectory=$2
  originalsDirectory=$3

  IFS=$'\n' allMediaFiles=($(find "$inputDirectory" ".*\.$allFormats" -type f))
  log "Found ${#allMediaFiles[@]} video files in [$inputDirectory]"
}

function filterFilesToEncode(){
  formatToEncode="$1"
  log "Filtering out files that are already hevc encoded..."

  for file in "${allMediaFiles[@]}"
  do
    fileEncoding=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")

    if [ "$fileEncoding" = "$formatToEncode" ]; then
      filesToEncode+=($file)
    fi
  done

  filesFiltered=$((${#allMediaFiles[@]}-${#filesToEncode[@]}))
  log "Filtered out $filesFiltered file(s) that was already encoded as hevc."
}

function processFiles(){
  outputFileEncoding="$1"

  # create error file if it doesn't exist
  touch $fileErrors
  touch $tmpErrorsFile

  # now begin the actual encoding on each of the files
  for file in "${filesToEncode[@]}"
  do
    # keeping track of the original file size. If it's smaller than the re-encoded version, delete the new file
    originalFileSize=$(getBytes "$file")

    log "Original file: '$file'"
    log "Original file size: $originalFileSize bytes"
    filename=$(basename -- "$file")
    newFileName="${filename}_HEVC.mp4"
    newFile="$inputDirectory/$newFileName"

    # can we do a more robust way to change the file extension here?
    log "Encoding video to: '$newFile'"
    args=$(getArgsFrom "$outputFileEncoding")
    command="ffmpeg -i '$file' $args '$newFile'"
    log "Executing [$command]"
    eval "$command"

    # does the file have any data? If no then it failed to be created
    fileSize=$(getBytes "$newFile")

    if [ "$fileSize" = "0" ] || test -z "$fileSize"; then
      log "Something went wrong when trying to encode file: '$newFile'" >> $fileErrors
      log "Something went wrong when trying to encode file: '$newFile'" >> $tmpErrorsFile
      continue
    fi

    log "New file size: $fileSize bytes"

    # if '-d' was not specified, skip
    if test -z "$4"; then
      log "Ignoring newly encoded file size."
    # if it was, and we're doing HEVC target encoding
    elif [ "$outputEncoding" = "$HEVC_ENCODING" ]; then
      # was the file size of the new file larger?
      if [ "$originalFileSize" \< "$fileSize" ]; then
        log "New file size was actually larger than the original, deleting the new file $newFile" >> $fileErrors
        rm -rf "$newFile"
        continue
      fi
    fi

    # verify the integrity of the newly created video file
    integrityErrorsFile="$outputDirectory/integrityFileErrors.log"
    eval "ffmpeg -v error -i '$newFile' -f null - 2>$integrityErrorsFile"
    anyErrors=$(grep 'error' "$integrityErrorsFile")
    if test -z "$anyErrors"; then
      log "No integrity issues found with file: '$newFile'"
    else
      log "Integrity issue found with file: '$newFile'" >> $fileErrors
      log "Integrity issue found with file: '$newFile'" >> $tmpErrorsFile
    fi

    # clear the integrity errors file
    rm -rf "$integrityErrorsFile"

    # move original to avoid re-encoding
    log "Moving file '$file' into folder pending deletion: [$originalsDirectory]"
    mkdir -p "$originalsDirectory"
    mv "$file" "$originalsDirectory/$filename"

    # finally move the finished encoded product to the outputs directory
    log "Moving finished file '$newFile' to output directory: [$outputDirectory]"
    mv "$newFile" "$outputDirectory/$newFileName"
  done

  # notify discord if supported about what happened
  notifyDiscordIfProvided "$outputEncoding" "$tmpErrorsFile"

  # clear the temporary log file
  rm -rf "$tmpErrorsFile"
}

# based on your target encoding format, returns pre-set args for ffmpeg
function getArgsFrom(){
  outputEncoding="$1"
  args=""

  if [ "$outputEncoding" = "$H264_ENCODING" ]; then
    args="$H264_ARGS"
  elif [ "$outputEncoding" = "$HEVC_ENCODING" ]; then
    args="$HEVC_ARGS"
  fi

  echo "$args"
}

# input: encodingOutput, errors
function notifyDiscordIfProvided(){
  encodingOutput="$1"
  errors="$2"

  if test -z "${DISCORD_WEBHOOK}"; then
    echo "Notifications to Discord not configured."
    return
  fi

  echo "Sending notifications to discord..."
  msg=""
  if test -z "$errors"; then
    msg="$DISCORD_ERRORS"
  else
    msg="$DISCORD_SUCCESS"
  fi

  curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST --data "{\"content\": \"$msg\"}" "$DISCORD_WEBHOOK"
}