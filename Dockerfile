FROM debian
RUN apt-get update && apt-get install -y \
        bash \
        curl \
        ethtool \
        net-tools \
        nicstat \
        procps \
        systemd \
        tcpdump \
        trace-cmd \
        && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /run/systemd
COPY hook.sh /hook.sh
COPY run.sh /run.sh
