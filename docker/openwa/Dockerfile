FROM openwa/wa-automate:latest

USER root

# Corregir fuentes de apt (clave caducada de chrome) e instalar procps
RUN rm -f /etc/apt/sources.list.d/google-chrome.list && \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y --no-install-recommends procps && \
    rm -rf /var/lib/apt/lists/*

USER owauser
