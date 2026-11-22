## Date:
11/22/2026

## Model Used:
ChatGPT

## Purpose:
The main purpose AI was used was to help me understand the main idea of the assignment, explain some of the networking and security concepts involved, and guide me through the implementation and testing of my assigned tasks. 

## Conversation Log Files:
My AI conversation log files are located in the root folder, under the name 'AI_Logs_NICOLE.txt'.

## What I Used:
I used ChatGPT's explanations to better understand concepts like packet captures, TCP streams, and Suricata rules. I also followed its guidance when implementing and testing Tasks 2 and 4.

## What I Changed:
I changed some of the suggested code and commands to make sure they worked properly in my VM and followed closely to what was being asked for in the actual assignment. 

## How I Tested It:
I ran the commands locally and checked their outputs to make sure that everything was working as expected. For Task 2, I used nmap, netcat, and tshark outputs to make sure the listener was working, I was able to capture traffic, and verify that the SHA-256 match. For Task 4, I checked my rules for any syntax issues and tested them against both the malicious and the clean PCAP files to make sure the expected alerts were generated. If there were any issues that needed to be troubleshooted, I attempted fixing it on my own before asking AI for assistance.

## One Error, Limitation, or Rejected Suggestion:
ChatGPT originally suggested using a tshark command that showed both the GET and POST requests. This wasn't wrong, but I really only needed the exfiltration traffic, so I changed the command to filter for TCP stream 1 so that it only showed the POST request.
