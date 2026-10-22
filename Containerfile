# Your plugin's image. BASE is the released base image in base.txt (base-cli for terminal apps,
# base-gui for window apps); the store refuses any other FROM.
ARG BASE
FROM ${BASE}
# Install what your app needs from Debian's archive, for example:
# RUN apt-get update && apt-get install -y --no-install-recommends htop && rm -rf /var/lib/apt/lists/*
COPY start.sh /usr/local/bin/start.sh
RUN chmod 755 /usr/local/bin/start.sh
