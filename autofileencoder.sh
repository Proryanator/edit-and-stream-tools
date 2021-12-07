# docker run \
# --mount type=bind,source="/Users/l260852/git/edit-and-stream-tools/input/",target=/input \
# --mount type=bind,source="/Users/l260852/git/edit-and-stream-tools/output/",target=/output \
# --mount type=bind,source="/Users/l260852/git/edit-and-stream-tools/originals/",target=/originals \
# -t proryanator/eas

docker run \
-it --entrypoint='bash' \
--mount type=bind,source="/Users/l260852/git/edit-and-stream-tools/input/",target=/input \
--mount type=bind,source="/Users/l260852/git/edit-and-stream-tools/output/",target=/output \
--mount type=bind,source="/Users/l260852/git/edit-and-stream-tools/originals/",target=/originals \
-t proryanator/eas
