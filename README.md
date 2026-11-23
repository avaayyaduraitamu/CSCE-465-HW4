# CSCE 465 - Detect and Block Agent Exfiltration 

## Project Overview

This project demonstrates how an AI agent can be exposed to an indirect prompt injection attack that leads to unauthorized network activity and data exfiltration. Using a local Docker network, we simulate the attack, capture and analyze the network traffic, implement firewall restrictions to prevent exfiltration, and create Suricata rules to detect malicious activity.

## Getting Started

### Requirements

- Ubuntu Linux VM
- Docker and Docker Compose
- Nmap
- tcpdump
- TShark
- Suricata
- Netcat
- iptables-nft
- curl

### Initial Setup

Open a terminal in the Ubuntu VM and navigate to the project directory:

```bash
cd ~/csce465-agentsec/hw4
```

Build and start the Docker containers:

```bash
docker compose up -d --build
```

Verify that all three containers are running:

```bash
docker compose ps
```

The project uses three containers:

| Container | IP Address | Purpose |
|---|---|---|
| agent-node | 172.30.0.10 | Executes the mock skill and stores the fake secret |
| web-lab | 172.30.0.40 | Hosts the benign and adversarial webpages |
| mock-c2 | 172.30.0.66 | Receives exfiltrated data |

All containers communicate through the isolated Docker network (`172.30.0.0/24`).

After completing the initial setup, follow the instructions for each task below.

---

## Task 1 - Build the Local Network Lab

*TO BE FILLED HERE*

---

## Task 2 - Scan, Capture, and Reconstruction

This task scans for the unauthorized listener on agent-node, captures the malicious network traffic, and uses TShark to reconstruct the exfiltration event.

Run the following commands from the `hw4` directory on the Ubuntu VM. Make sure the Docker containers are running (`docker compose up -d`) and that the Task 3 firewall restrictions are not active.

### 1. Start and Verify the Listener

Start the mock listener on agent-node:

```bash
docker compose exec -T agent-node sh /opt/mock_skill.sh
```

Scan the agent-node for TCP port 9009:

```bash
nmap -sT -p 9009 172.30.0.10
```

Verify the listener using Netcat:

```bash
nc -w 3 172.30.0.10 9009
```

**Expected result:** Port 9009 is open, and Netcat returns `HW4-mock-listener`.

### 2. Capture Malicious Traffic

In the first terminal, start the packet capture:

```bash
sudo tcpdump -i br-hw4 -s 0 -w hw4-malicious.pcap 'net 172.30.0.0/24'
```

While the capture is running, use a second terminal to fetch the adversarial webpage:

```bash
docker compose exec -T agent-node curl http://172.30.0.40:8000/adversarial.html
```

Then trigger the exfiltration:

```bash
docker compose exec -T agent-node sh /opt/mock_skill.sh exfiltrate-course-file
```

Stop the packet capture with `Ctrl+C` in the first terminal.

### 3. Reconstruct the Traffic

Display the HTTP requests:

```bash
tshark -r hw4-malicious.pcap -Y "http.request" -T fields -e ip.src -e tcp.srcport -e ip.dst -e tcp.dstport -e http.request.method -e http.request.uri -e tcp.stream
```

Follow TCP stream 1 to view the POST request and fake token:

```bash
tshark -r hw4-malicious.pcap -q -z follow,tcp,ascii,1
```

Extract the HTTP objects and verify the SHA-256 hash:

```bash
mkdir -p objs
tshark -r hw4-malicious.pcap -q --export-objects http,objs/
sha256sum 'objs/%2f'
sha256sum fake_secrets.txt
```

Display the exfiltration stream's packet timestamps:

```bash
tshark -r hw4-malicious.pcap -Y "tcp.stream == 1" -T fields -e frame.number -e frame.time
```

**Expected result:** The capture contains a GET request for `/adversarial.html` followed by a POST request to mock-c2. The extracted POST body should have the same SHA-256 hash as `fake_secrets.txt`.

*Note: The stream number and exported object filename are based on our capture. They may differ if the traffic is captured again.*

### 4. Capture Clean Traffic

Start a separate capture:

```bash
sudo tcpdump -i br-hw4 -s 0 -w hw4-clean.pcap 'net 172.30.0.0/24'
```

In another terminal, request the benign webpage:

```bash
docker compose exec -T agent-node curl http://172.30.0.40:8000/benign.html
```

Stop the capture using `Ctrl+C`.

Verify the HTTP requests:

```bash
tshark -r hw4-clean.pcap -Y "http.request" -T fields -e ip.src -e ip.dst -e tcp.dstport -e http.request.method -e http.request.uri
```

**Expected result:** The clean capture contains a GET request for `/benign.html` without exfiltration traffic.

---
## Task 3 - Default-Deny Egress for the Agent Container 


### 1. Install the Firewall Rules

Run the following commands from the `hw4` directory:

```bash
cd ~/csce465-agentsec/hw4
sudo ./firewall.sh
```

The script enables iptables processing for bridged Docker traffic:

```bash
modprobe br_netfilter
sysctl -w net.bridge.bridge-nf-call-iptables=1
```

To remove the course firewall rules when finished:

```bash
sudo ./firewall-reset.sh
```

### 2. Firewall Policy

The `HW4-EGRESS` chain is connected to Docker's `DOCKER-USER` chain and applies the following rules:

| Rule | Action | Purpose |
|---|---|---|
| 1 | ACCEPT `ESTABLISHED,RELATED` traffic from the agent | Allows established and related traffic. |
| 2 | ACCEPT `ESTABLISHED,RELATED` traffic to the agent | Allows return traffic to the agent. |
| 3 | ACCEPT agent-to-web TCP port 8000 | Allows legitimate web access. |
| 4 | LOG new agent-to-mock-C2 TCP port 8080 connections | Logs unauthorized connection attempts. |
| 5 | DROP new agent-to-mock-C2 TCP port 8080 connections | Blocks mock-C2 connections. |
| 6 | DROP other new forwarded connections from the agent | Blocks other unauthorized outbound connections. |
| 7 | RETURN all remaining traffic | Leaves unrelated Docker traffic unchanged. |

### 3. Firewall Verification

Run all five tests with the Docker containers running and the firewall installed.

**Test 1: Fetch the benign webpage**

```bash
docker compose exec agent-node curl -i --max-time 5 http://172.30.0.40:8000/benign.html
```

Expected result: HTTP `200 OK`.

Result: **PASS** — The benign webpage returned HTTP `200 OK`.

**Test 2: Attempt to send the fake secret to mock-c2**

```bash
docker compose exec agent-node /opt/mock_skill.sh exfiltrate-course-file
```

Check whether the C2 server received a file:

```bash
docker compose exec mock-c2 ls -l /data
```

Expected result: The request times out, and no new `/data/received.bin` appears.

Result: **PASS** — The request timed out after approximately 10 seconds, and `/data` was empty when checked.

**Test 3: Attempt to connect to another unapproved container port**

```bash
docker compose exec agent-node curl -v --max-time 5 http://172.30.0.40:8080/
```

Expected result: The connection times out.

Result: **PASS** — The connection timed out after approximately 5 seconds.

**Test 4: Verify established response traffic**

Start the mock listener in the agent container:

```bash
docker compose exec -d agent-node socat TCP-LISTEN:9009,reuseaddr,fork SYSTEM:'printf "HW4 mock listener\n"'
```

From the VM host, connect to the listener:

```bash
nc -v -w 3 172.30.0.10 9009
```

Expected result: The connection succeeds and the listener returns its banner.

Result: **PASS** — Netcat successfully connected to TCP port `9009` and received listener output.

**Test 5: Verify unrelated Docker traffic**

```bash
docker compose exec web-lab curl -i --max-time 5 -X POST http://172.30.0.66:8080/
```

Expected result: HTTP `204 No Content`.

Result: **PASS** — The POST request returned HTTP `204 No Content`.

### 4. Firewall Counters and Kernel Logs

Display the custom firewall chain and its packet counters:

```bash
sudo iptables -L HW4-EGRESS -n -v --line-numbers
```

Verify the jump from `DOCKER-USER`:

```bash
sudo iptables -L DOCKER-USER -n -v --line-numbers
```

Display the kernel log entries for blocked mock-C2 connections:

```bash
sudo dmesg | grep "HW4-C2-DROP" | tail -20
```

The observed firewall counters were:

| Firewall rule | Packets | Bytes |
|---|---:|---:|
| Established/related traffic from agent | 11 | 754 |
| Established/related traffic to agent | 11 | 1,368 |
| Allowed agent-to-web TCP 8000 | 3 | 180 |
| Logged agent-to-mock-C2 TCP 8080 | 26 | 1,560 |
| Dropped agent-to-mock-C2 TCP 8080 | 26 | 1,560 |
| Dropped other new agent connections | 10 | 600 |
| Returned unrelated traffic | 20 | 1,436 |

The jump from `DOCKER-USER` to `HW4-EGRESS` recorded 81 packets and 5,898 bytes.

The kernel logs contained entries with the prefix `HW4-C2-DROP:` and the following identifying fields:

```text
IN=br-hw4 OUT=br-hw4
SRC=172.30.0.10 DST=172.30.0.66
PROTO=TCP ... DPT=8080 ... SYN
```

These entries confirm that connection attempts from `agent-node` to `mock-c2` were logged. The LOG and DROP rules each recorded 26 packets and 1,560 bytes. Packet counts include retransmissions and do not necessarily represent separate connections.

All five firewall verification tests passed.

For the detailed rule-by-rule explanation, firewall design, and security analysis, refer to the Task 3 section of `report.pdf`.

---

## Task 4 - The Three Suricata Rules

This task uses three custom Suricata rules in `local.rules` to detect fake token exfiltration, an indirect prompt injection marker, and TCP connection attempts to mock-c2.

### 1. Validate the Rules

View the rules:

```bash
cat local.rules
```

Check that Suricata can load them successfully:

```bash
sudo suricata -T -S local.rules -c /etc/suricata/suricata.yaml
```

**Expected result:** Suricata reports that the configuration was successfully loaded without errors.

### 2. Test the Malicious PCAP

Create the output directory and run Suricata:

```bash
mkdir -p suricata-malicious
sudo suricata -k none -r hw4-malicious.pcap -S local.rules -l suricata-malicious
```

View the generated alerts:

```bash
cat suricata-malicious/fast.log
```

**Expected result:** All three rules generate alerts:

- SID `1000001` — Fake Secret Exfiltration
- SID `1000002` — Indirect Prompt Injection Marker
- SID `1000003` — Known Mock C2 Connection

### 3. Test the Clean PCAP

Create the output directory and run Suricata against the clean capture:

```bash
mkdir -p suricata-clean
sudo suricata -k none -r hw4-clean.pcap -S local.rules -l suricata-clean
```

View the alerts:

```bash
cat suricata-clean/fast.log
```

**Expected result:** No alerts are generated for the clean traffic.

### 4. Evaluation Results

| Rule SID | Malicious PCAP | Clean PCAP |
|---|---|---|
| 1000001 | True Positive | True Negative |
| 1000002 | True Positive | True Negative |
| 1000003 | True Positive | True Negative |

All three rules successfully detected their expected malicious activity without generating alerts on the clean capture.

For detailed packet reconstruction, rule explanations, and screenshots of the results, refer to `report.pdf`.
