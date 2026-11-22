#!/bin/bash
set -e

CHAIN="HW4-EGRESS"

# Remove only jumps from DOCKER-USER to our course chain.
while iptables -C DOCKER-USER -j "$CHAIN" 2>/dev/null; do
    iptables -D DOCKER-USER -j "$CHAIN"
done

# Remove our chain and its rules, if it exists.
if iptables -L "$CHAIN" -n >/dev/null 2>&1; then
    iptables -F "$CHAIN"
    iptables -X "$CHAIN"
fi

echo "HW4 egress firewall rules removed."
