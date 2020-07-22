FROM debian
RUN apt-get update && apt-get install -y \
        bash \
        net-tools \
        nicstat \
        systemd \
        tcpdump \
        && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /run/systemd
COPY run.sh /run.sh
