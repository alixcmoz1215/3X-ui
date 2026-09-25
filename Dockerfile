FROM ghcr.io/mhsanaei/3x-ui:latest

# ---- Auto-setup scripts ----
COPY entrypoint-wrapper.sh /app/entrypoint-wrapper.sh
COPY setup-inbound.sh /app/setup-inbound.sh

RUN chmod +x /app/entrypoint-wrapper.sh /app/setup-inbound.sh

# Panel + inbound share this single port on Railway (Railway only
# exposes ONE public port per service, so panel and the VLESS/WS
# inbound must listen behind the same port and be routed by path).
ENV XUI_PANEL_PORT=8080 \
    XRAY_INBOUND_PORT=8080

EXPOSE 8080

# Wrap the image's original startup so we can inject our own
# "create inbound on first boot" logic without touching the
# upstream binary.
ENTRYPOINT ["/app/entrypoint-wrapper.sh"]
