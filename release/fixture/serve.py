#!/usr/bin/env python3
"""Test fixture for release/test-plan.md: a tiny HTTP server on the host.

    python3 -I release/fixture/serve.py PORT LOGFILE PLATFORM

Serves:
  /            a page titled "Envoi test page <PLATFORM>" with a form
  /submit?q=   logs "q=<value>" to LOGFILE and echoes it
  /sample.zip  a small zip file (for the download/BEOS:TYPE check)
Every request is logged to LOGFILE.
"""
import http.server
import io
import sys
import urllib.parse
import zipfile

PORT, LOG, PLATFORM = int(sys.argv[1]), sys.argv[2], sys.argv[3]


def log(line):
    with open(LOG, "a") as f:
        f.write(line + "\n")


def sample_zip():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        z.writestr("hello.txt", "hello from %s\n" % PLATFORM)
    return buf.getvalue()


class Handler(http.server.BaseHTTPRequestHandler):
    def send(self, body, ctype):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urllib.parse.urlsplit(self.path)
        log("GET " + self.path)
        if url.path == "/":
            page = ("<!doctype html><title>Envoi test page %s</title>"
                    "<h1>Envoi test page %s</h1>"
                    "<form action=/submit><input name=q autofocus>"
                    "<button>Send</button></form>"
                    "<p><a href=/sample.zip>sample.zip</a>") % (PLATFORM, PLATFORM)
            self.send(page.encode(), "text/html; charset=utf-8")
        elif url.path == "/submit":
            q = urllib.parse.parse_qs(url.query).get("q", [""])[0]
            log("q=" + urllib.parse.quote_plus(q))
            self.send(("<title>Got it</title><p>Got: %s" % q).encode(),
                      "text/html; charset=utf-8")
        elif url.path == "/sample.zip":
            self.send(sample_zip(), "application/zip")
        else:
            self.send_error(404)

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
