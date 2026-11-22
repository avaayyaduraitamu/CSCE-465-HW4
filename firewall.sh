#!/bin/bash
set -e

# Enable iptables processing for bridged Docker traffic.
modprobe br_netfilter
sysctl -w net.bridge.bridge-nf-call-iptables=1

AGENT="172.30.0.10"
WEB="172.30.0.40"
C2="172.30.0.66"
CHAIN="HW4-EGRESS"

# Create our own chain if it does not already exist.
iptables -N "$CHAIN" 2>/dev/null || true

# Clear our chain so rerunning this script does not duplicate rules.
iptables -F "$CHAIN"

# Add our jump from DOCKER-USER only if it is not already present.
iptables -C DOCKER-USER -j "$CHAIN" 2>/dev/null || \
    iptables -I DOCKER-USER 1 -j "$CHAIN"

# 1. Allow established and related traffic involving agent-node.
iptables -A "$CHAIN" -s "$AGENT" \
    -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A "$CHAIN" -d "$AGENT" \
    -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 2. Allow agent-node to access web-lab on TCP port 8000.
iptables -A "$CHAIN" -s "$AGENT" -d "$WEB" \
    -p tcp --dport 8000 \
    -m conntrack --ctstate NEW -j ACCEPT

# 3. Log new connections from agent-node to mock-c2:8080.
iptables -A "$CHAIN" -s "$AGENT" -d "$C2" \
    -p tcp --dport 8080 \
    -m conntrack --ctstate NEW \
    -j LOG --log-prefix "HW4-C2-DROP: " --log-level 4

# Drop those mock-C2 connections.
iptables -A "$CHAIN" -s "$AGENT" -d "$C2" \
    -p tcp --dport 8080 \
    -m conntrack --ctstate NEW -j DROP

# 4. Drop all other new forwarded connections from agent-node.
iptables -A "$CHAIN" -s "$AGENT" \
    -m conntrack --ctstate NEW -j DROP

# 5. Return unrelated traffic to Docker's normal processing.
iptables -A "$CHAIN" -j RETURN

echo "HW4 egress firewall rules installed."
