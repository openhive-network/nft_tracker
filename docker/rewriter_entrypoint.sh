#!/bin/sh

# Default value for REWRITE_LOG is off, unless explicitly set to 'on'
if [ "$REWRITE_LOG" = "on" ]; then
    REWRITE_LOG="rewrite_log on;"
else
    REWRITE_LOG="# rewrite_log off;"
fi

# The DNS server nginx re-resolves the PostgREST's name with: RESOLVER if set, else
# the container's first nameserver (Docker's embedded DNS on a compose network)
if [ -z "$RESOLVER" ]; then
    RESOLVER="$(awk '$1 == "nameserver" { print $2; exit }' /etc/resolv.conf 2>/dev/null)"
    case "$RESOLVER" in
        *:*) RESOLVER="[$RESOLVER]" ;;
    esac
    RESOLVER="${RESOLVER:-127.0.0.11}"
fi

# Use sed to replace the placeholders in the nginx template file
sed -e "s|\${REWRITE_LOG}|$REWRITE_LOG|g" -e "s|\${RESOLVER}|$RESOLVER|g" \
    /usr/local/openresty/nginx/conf/nginx.conf.template > /usr/local/openresty/nginx/conf/nginx.conf

# Start nginx
exec /usr/local/openresty/bin/openresty -g 'daemon off;'
