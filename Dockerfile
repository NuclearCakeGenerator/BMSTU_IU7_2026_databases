FROM postgres:latest

# Install python and the postgres extension
RUN apt-get update && apt-get install -y \
    postgresql-plpython3-${PG_MAJOR} \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*
