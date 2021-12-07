FROM jrottenberg/ffmpeg
COPY scripts/*.sh tools/
COPY watchforfiles.sh .

# make all tools in there executeable
RUN find tools -type f -iname "*.sh" -exec chmod +x {} \;

ENTRYPOINT ./watchforfiles.sh