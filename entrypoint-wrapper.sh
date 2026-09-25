#!/bin/sh
# ------------------------------------------------------------------
# Wrapper entrypoint for the 3x-ui image.
# 1. Starts the real x-ui panel (upstream binary/entrypoint).
# 2. In parallel, runs setup-inbound.sh which waits for the panel's
#    API to be reachable, logs in, and (only the very first time)
#    creates the "جینکس | Super JinX" VLESS+WS inbound automatically
#    so the config works the moment the deploy finishes.
# ------------------------------------------------------------------
set -e

# Kick off the panel itself (this is the upstream image's normal
# start command). NOTE: depending on the exact base image tag, this
# may be `/app/x-ui` directly instead of a docker-entrypoint.sh —
# check the image you pulled and adjust this one line if the
# container fails to start.
if [ -x /app/docker-entrypoint.sh ]; then
    /app/docker-entrypoint.sh &
else
    /app/x-ui &
fi
XUI_PID=$!

# Run the auto-inbound-setup script in the background so it doesn't
# block panel startup.
/app/setup-inbound.sh &

# Keep the container alive as long as the panel process is alive.
wait "$XUI_PID"
