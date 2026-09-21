#!/usr/bin/env python3
"""Local preview that mirrors Vercel's cleanUrls behaviour.

Vercel serves join.html at /join, so the pages link to /join rather than
/join.html. Python's stock http.server would 404 on that, which would mean
local preview and production disagree — so resolve extensionless paths to
their .html file the same way Vercel does.

    python3 scripts/serve.py [port]
"""
import http.server
import os
import sys

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.path = self._resolve(self.path)
        return super().do_GET()

    def do_HEAD(self):
        self.path = self._resolve(self.path)
        return super().do_HEAD()

    def _resolve(self, path):
        bare = path.split('?')[0].split('#')[0]
        if bare.endswith('/') or os.path.splitext(bare)[1]:
            return path
        candidate = bare.lstrip('/') + '.html'
        return '/' + candidate if os.path.isfile(candidate) else path

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 4173
    http.server.test(HandlerClass=Handler, port=port, bind='127.0.0.1')
