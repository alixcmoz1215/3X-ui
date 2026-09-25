#!/bin/sh
# ------------------------------------------------------------------
# Waits for the x-ui panel to come up, logs in with the admin
# credentials, and creates one VLESS + WebSocket + TLS inbound
# automatically — so the deploy is ready to use with zero manual
# clicking. Safe to run on every boot: it checks first and skips
# creation if an inbound with the same remark already exists.
# ------------------------------------------------------------------
set -u

PANEL_PORT="${XUI_PANEL_PORT:-8080}"
BASE_URL="http://127.0.0.1:${PANEL_PORT}"
COOKIE_JAR="/tmp/xui-cookie.txt"

ADMIN_USER="${XUI_USERNAME:-admin}"
ADMIN_PASS="${XUI_PASSWORD:-admin}"

INBOUND_REMARK="جینکس | Super JinX"
# Defaults to the UUID you gave us — override with the INBOUND_UUID
# Railway variable if you ever want a different one.
INBOUND_UUID="${INBOUND_UUID:-df70a084-8d46-50bd-dec8-3a0f41903f3a}"
WS_PATH="/ws/${INBOUND_UUID}"

# Subscription (sub-link) service settings.
SUB_PORT="${XUI_SUB_PORT:-${XUI_PANEL_PORT:-8080}}"
SUB_PATH="${XUI_SUB_PATH:-/sub/}"

# Railway injects the public domain of the service here.
DOMAIN="${RAILWAY_PUBLIC_DOMAIN:-${RAILWAY_STATIC_URL:-localhost}}"

log() { echo "[setup-inbound] $*"; }

# 1) Wait until the panel actually answers.
i=0
until curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}/login" | grep -q "200"; do
    i=$((i + 1))
    if [ "$i" -gt 60 ]; then
        log "panel never came up after 60 tries, giving up."
        exit 0
    fi
    sleep 2
done
log "panel is up."

# 2) Log in and keep the session cookie.
curl -s -c "$COOKIE_JAR" -X POST "${BASE_URL}/login" \
    -d "username=${ADMIN_USER}" \
    -d "password=${ADMIN_PASS}" >/dev/null

# 3) Bail out if an inbound with this remark already exists
#    (prevents duplicates on container restarts/redeploys).
EXISTING=$(curl -s -b "$COOKIE_JAR" "${BASE_URL}/panel/api/inbounds/list")
if echo "$EXISTING" | grep -q "$INBOUND_REMARK"; then
    log "inbound '${INBOUND_REMARK}' already exists, skipping."
    exit 0
fi

# 4) Build the inbound payload (VLESS + WS + TLS-at-edge, since
#    Railway terminates TLS for you on the public domain — inside
#    the container we just speak plain HTTP/WS on XRAY_INBOUND_PORT).
SETTINGS=$(cat <<EOF
{"clients":[{"id":"${INBOUND_UUID}","email":"jinx","enable":true,"flow":""}],"decryption":"none","fallbacks":[]}
EOF
)

STREAM_SETTINGS=$(cat <<EOF
{"network":"ws","security":"none","wsSettings":{"path":"${WS_PATH}","headers":{}}}
EOF
)

curl -s -b "$COOKIE_JAR" -X POST "${BASE_URL}/panel/api/inbounds/add" \
    --data-urlencode "up=0" \
    --data-urlencode "down=0" \
    --data-urlencode "total=0" \
    --data-urlencode "remark=${INBOUND_REMARK}" \
    --data-urlencode "enable=true" \
    --data-urlencode "expiryTime=0" \
    --data-urlencode "listen=" \
    --data-urlencode "port=${XRAY_INBOUND_PORT:-8080}" \
    --data-urlencode "protocol=vless" \
    --data-urlencode "settings=${SETTINGS}" \
    --data-urlencode "streamSettings=${STREAM_SETTINGS}" \
    --data-urlencode "sniffing={\"enabled\":true,\"destOverride\":[\"http\",\"tls\"]}" \
    >/tmp/xui-add-inbound.log 2>&1

if grep -q '"success":true' /tmp/xui-add-inbound.log; then
    log "inbound created successfully."
    log "vless://${INBOUND_UUID}@${DOMAIN}:443?path=${WS_PATH}&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${INBOUND_REMARK}"
else
    log "inbound creation may have failed, check /tmp/xui-add-inbound.log"
    cat /tmp/xui-add-inbound.log
fi

# 5) Turn on the subscription server so the sub-link works out of
#    the box, sharing the same public Railway domain/port (no
#    separate port to expose, no manual toggling in the UI).
curl -s -b "$COOKIE_JAR" -X POST "${BASE_URL}/panel/setting/update" \
    --data-urlencode "subEnable=true" \
    --data-urlencode "subTitle=JinX Sub" \
    --data-urlencode "subDomain=${DOMAIN}" \
    --data-urlencode "subPort=${SUB_PORT}" \
    --data-urlencode "subPath=${SUB_PATH}" \
    --data-urlencode "subUpdates=12" \
    >/tmp/xui-sub-setting.log 2>&1

if grep -q '"success":true' /tmp/xui-sub-setting.log; then
    log "subscription service enabled."
    log "sub-link: https://${DOMAIN}${SUB_PATH}${INBOUND_UUID}"
else
    log "sub-service update may have failed, check /tmp/xui-sub-setting.log"
    cat /tmp/xui-sub-setting.log
fi
