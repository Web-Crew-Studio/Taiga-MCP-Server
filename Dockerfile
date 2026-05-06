FROM ghcr.io/talhaorak/pytaiga-mcp:latest

USER root
COPY docker/patch_upstream.py /tmp/patch_upstream.py
RUN /app/.venv/bin/python /tmp/patch_upstream.py && rm /tmp/patch_upstream.py

USER appuser
ENTRYPOINT ["/app/.venv/bin/python", "src/server.py"]
