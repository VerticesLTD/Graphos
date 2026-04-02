#!/usr/bin/env python3
"""Serve `export/` over HTTP for local Web builds.

Godot's **Run** on the Web preset sometimes fails with
`Error starting HTTP server: 22` (invalid bind / port in use). Export the
project, then run this and open the printed URL instead.

Usage (from repo root):  python3 scripts/serve_web_export.py
"""
from __future__ import annotations

import http.server
import os
import socketserver

PORT = 8080
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
EXPORT_DIR = os.path.join(ROOT, "export")


def main() -> None:
	if not os.path.isdir(EXPORT_DIR):
		raise SystemExit("Missing export/ — export the Web preset from Godot first.")
	os.chdir(EXPORT_DIR)
	handler = http.server.SimpleHTTPRequestHandler
	socketserver.TCPServer.allow_reuse_address = True
	with socketserver.TCPServer(("127.0.0.1", PORT), handler) as httpd:
		print("Serving %s" % EXPORT_DIR)
		print("Open http://127.0.0.1:%s/Graphos.html" % PORT)
		print("(If port is busy, edit PORT in this script.)")
		httpd.serve_forever()


if __name__ == "__main__":
	main()
