docker run \
--mount type=bind,source="$(pwd)/input/",target=/input \
--mount type=bind,source="$(pwd)/output/",target=/output \
--mount type=bind,source="$(pwd)/originals/",target=/originals \
-t proryanator/hevctoh264sniffer \
-h "hevctoh264sniffer"