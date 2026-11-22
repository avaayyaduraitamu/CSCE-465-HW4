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

*TO BE FILLED HERE*

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
