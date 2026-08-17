#!/usr/bin/env python3
import socket
import json
import sys

UDP_PORT = 9876
HTTP_PORT = 8080

def get_host_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("8.8.8.8", 80))
    ip = s.getsockname()[0]
    s.close()
    return ip

def main():
    host_ip = get_host_ip()
    print(f"UDP Discovery on port {UDP_PORT}, host={host_ip}", flush=True)
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.bind(("0.0.0.0", UDP_PORT))
    print(f"Listening...", flush=True)
    
    while True:
        data, addr = sock.recvfrom(1024)
        message = data.decode("utf-8").strip()
        if message == "discover_family_finance":
            response = json.dumps({
                "magic": "family_finance_server",
                "ip": host_ip,
                "port": HTTP_PORT,
                "name": "家庭记账服务器",
            })
            sock.sendto(response.encode("utf-8"), addr)
            print(f"Request from {addr[0]}, responded {host_ip}:{HTTP_PORT}", flush=True)

if __name__ == "__main__":
    main()
