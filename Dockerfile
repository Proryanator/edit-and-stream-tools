FROM jrottenberg/ffmpeg
COPY scripts/*.sh .
COPY watchforfiles.sh .

# make all tools in there executeable
RUN find . -type f -iname "*.sh" -exec chmod +x {} \;

# ENTRYPOINT ./watchforfiles.sh
ENTRYPOINT ./hevc-to-h264.sh /input /output /originals