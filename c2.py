from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(n)

        Path("/data/received.bin").write_bytes(body)

        print(f"Received {len(body)} bytes", flush=True)

        self.send_response(204)
        self.end_headers()


HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
