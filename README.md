# edit-and-stream-tools
A library of scripting tools that I use to make my life easier as a content creator.

Mostly pre-configured runs of ffmpeg to run on Nvidia GPU's, and a docker image to run 24/7 looking for h265/hevc files to transcode to h264.

## hevctoh264
A tool that contains pre-defined lossless conversion from hevc to h254 (for programs that don't support hevc).
  
## hevctool:
A tool to losslessly convert h264 to h265/hevc for space saving.

## proryanator/hevctoh264sniffer: a video file sniffer that converts hevc to h264

Build with the following by hand:

```bash
docker build . -t proryanator/hevctoh264sniffer
```

Or use the included shell script if on unix:
```bash
builddockerimage.sh
```


## Running the sniffer

You can run the sniffer simly via
If you so desire, you can hook this into your discord server to alert you when video processing is finished.
```bash
docker run -t proryanator/hevctoh264sniffer -env DISCORD_WEBHOOK=YOURWEBHOOK
```