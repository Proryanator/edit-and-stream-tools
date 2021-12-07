docker run \
--mount type=bind,source="$(pwd)/input/",target=/input \
--mount type=bind,source="$(pwd)/output/",target=/output \
--mount type=bind,source="$(pwd)/originals/",target=/originals \
-e DISCORD_WEBHOOK="$1" \
-t proryanator/hevctoh264sniffer \
-h "hevctoh264sniffer"