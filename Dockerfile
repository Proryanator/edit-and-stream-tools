FROM linuxserver/ffmpeg
COPY scripts/*.sh .
COPY watchforfiles.sh .

# make all tools in there executeable
RUN find . -type f -iname "*.sh" -exec chmod +x {} \;

ENTRYPOINT ./watchforfiles.sh
# ENTRYPOINT ./hevctool.sh /input /output /originals