FROM --platform=$TARGETPLATFORM ubuntu:22.04
RUN mkdir -p /other
WORKDIR /other/
ENTRYPOINT [ "/bin/bash", "-c", "pwd" ]