import asyncio
import json
import socket

UDP_PORT = 9876
HTTP_PORT = 8000
RESPONSE_MAGIC = "family_finance_server"


def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "0.0.0.0"


async def udp_discovery_server():
    loop = asyncio.get_event_loop()
    transport, protocol = await loop.create_datagram_endpoint(
        lambda: UDPDiscoveryProtocol(),
        local_addr=("0.0.0.0", UDP_PORT),
        allow_broadcast=True,
    )
    try:
        await asyncio.Future()
    finally:
        transport.close()


class UDPDiscoveryProtocol:
    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        try:
            message = data.decode("utf-8").strip()
            if message == "discover_family_finance":
                ip = get_local_ip()
                response = json.dumps({
                    "magic": RESPONSE_MAGIC,
                    "ip": ip,
                    "port": HTTP_PORT,
                    "name": "家庭记账服务器",
                })
                self.transport.sendto(response.encode("utf-8"), addr)
        except Exception:
            pass
