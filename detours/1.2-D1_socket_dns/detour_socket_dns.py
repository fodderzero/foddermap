#!/usr/bin/env python3
"""
Detour 1.2-D1: Raw Socket DNS Query Experiment
Goal: Send a raw DNS query for an A record and receive the response
"""

import socket
import struct
import random

def build_dns_query(domain: str) -> bytes:
    """
    Build a raw DNS query packet for an A record.
    """
    # Generate a random transaction ID (2 bytes)
    transaction_id = random.randint(0, 65535)

    # DNS Header (12 bytes)
    # Format: Transaction ID, Flags, QDCOUNT, ANCOUNT, NSCOUNT, ARCOUNT
    header = struct.pack(
        "!HHHHHH",
        transaction_id,     # Transaction ID
        0x0100,             # Flags: Standard query, recursion desired
        1,                  # QDCOUNT (1 question)
        0,                  # ANCOUNT (0 answers)
        0,                  # NSCOUNT (0 authority records)
        0,                  # ARCOUNT (0 additional records)
    )

    # Question Section - Encode the domain name 
    # DNS uses "label" format: length + label + length + label + 0x00
    qname = b""
    for label in domain.split("."):
        qname += bytes([len(label)]) + label.encode("utf-8")
    qname += b"\x00" # Null terminator for the domain name (required by DNS)

    # QTYPE (2 bytes) - 1 = A record
    qtype = struct.pack("!H", 1)

    # QCLASS (2 bytes) - 1 = IN (Internet)
    qclass = struct.pack("!H", 1)

    # Full DNS query packet
    query = header + qname + qtype + qclass
    return query


def parse_name(data: bytes, offset: int) -> tuple[str, int]:
    """
    Parse a DNS name from the response.
    """
    labels = []
    while True:
        length = data[offset]
        if length == 0:
            offset += 1
            break
        labels.append(data[offset + 1:offset + 1 + length].decode("utf-8"))
        offset += 1 + length
    return ".".join(labels), offset


def main():
    # DNS server to query (Google's public DNS)
    dns_server = "8.8.8.8"
    dns_port = 53

    # Target domain (using example.com for now)
    domain = "example.com"

    print(f"[*] Building raw DNS query for {domain}")

    query_packet = build_dns_query(domain)
    print(f"[*] Query packet built: ({len(query_packet)} bytes)")

    # Create a UDP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(5) # 5 second timeout

    try:

        print(f"[*] Sending query to {dns_server, dns_port}")
        sock.sendto(query_packet, (dns_server, dns_port))
        print("[*] Query sent successfully!")

        print("[*] Waiting for response...")
        response, server = sock.recvfrom(4096)
        print(f"[*] Received {len(response)} bytes from {server}")

        # Parse the header first (first 12 bytes)
        header = response[:12]
        (
            tx_id,
            flags,
            qdcount,
            ancount,
            nscount,
            arcount
        ) = struct.unpack("!HHHHHH", header)

        print(f"\n=== DNS Response Header ===")
        print(f"Transaction ID: {tx_id}")
        print(f"Flags: {hex(flags)}")
        print(f"Questions: {qdcount} | Answers: {ancount}")
        # print(f"Answers: {ancount}")
        # print(f"Authority: {nscount}")
        # print(f"Additional {arcount}")

        offset = 12
        for _ in range(qdcount):
            _, offset = parse_name(response, offset)
            offset += 4 # Skip QTYPE + QCLASS (2 bytes each)
        
        print(f"[*] Skipped question section. Now at byte offset: {offset}")

        # Start parsing answers
        print(f"\n === Answer Section (first pass) ===")
        for i in range(ancount):
            print(f"\n[Answer {i+1}]")
            name, offset = parse_name(response, offset)
            print(f"  Name: {name}")

            atype, aclass, ttl, rdlength = struct.unpack("!HHIH", response[offset:offset+10])
            offset += 10
            print(f"  Type: {atype} | Class: {aclass} | TTL: {ttl} | RDLength: {rdlength}")

            # For A records, RData is just an IP address (4 bytes)
            if atype == 1 and rdlength == 4:
                ip = ".".join(str(b) for b in response[offset:offset+4])
                print(f"  IP Address: {ip}")
                offset += 4
            else:
                offset += rdlength # Skip unknown record types for now

    except socket.timeout:
        print("[*] Timeout waiting for response")
    except Exception as e:
        print(f"[!] Error: {e}")
    finally:
        sock.close()


if __name__ == "__main__":
    main()