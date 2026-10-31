FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends nodejs git \
    && pip install --no-cache-dir ansible-core==2.18.2 ansible-lint==25.1.3 \
    && rm -rf /var/lib/apt/lists/*
