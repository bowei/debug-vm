FROM debian
RUN apt-get update && apt-get install -y \
        bash \
        tcpdump \
        && rm -rf /var/lib/apt/lists/*
