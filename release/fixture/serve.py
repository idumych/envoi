#!/usr/bin/env python3
"""Test fixture for release/test-plan.md: a tiny HTTP server on the host.

    python3 -I release/fixture/serve.py PORT LOGFILE PLATFORM

Serves:
  /            a page titled "Envoi test page <PLATFORM>" with a form
  /submit?q=   logs "q=<value>" to LOGFILE and echoes it
  /sample.zip  a small zip file (for the download/BEOS:TYPE check)
  /webrtc      a WebRTC loopback test (results also logged as "webrtc <line>")
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


# /webrtc: a loopback call inside one page (camera and microphone, two peer
# connections, a data channel). Each result is a line of text on the page and
# a GET /result?r=... in the log. Needs media.navigator.permission.disabled.
WEBRTC_PAGE = """<!doctype html><title>WebRTC test</title>
<style>body{font:18px sans-serif} pre{font-size:20px}</style>
<h1>WebRTC test</h1><pre id=log></pre>
<video id=local autoplay muted width=240></video>
<video id=remote autoplay width=240></video>
<script>
function out(t) {
  document.getElementById("log").textContent += t + "\\n";
  new Image().src = "/result?r=" + encodeURIComponent(t);
}
async function run() {
  let stream = null;
  try {
    stream = await navigator.mediaDevices.getUserMedia({video: true, audio: true});
  } catch (e) {
    out("getUserMedia audio+video FAIL " + e.name);
    for (const c of [{video: true}, {audio: true}]) {
      try { stream = await navigator.mediaDevices.getUserMedia(c); break; }
      catch (e2) { out("getUserMedia " + Object.keys(c)[0] + " FAIL " + e2.name); }
    }
  }
  if (stream) {
    out("camera tracks " + stream.getVideoTracks().length +
        " microphone tracks " + stream.getAudioTracks().length);
    const local = document.getElementById("local");
    local.srcObject = stream;
    await new Promise(r => { local.onloadedmetadata = r; setTimeout(r, 5000); });
    out("local video " + local.videoWidth + "x" + local.videoHeight);
  }
  const pc1 = new RTCPeerConnection(), pc2 = new RTCPeerConnection();
  pc1.onicecandidate = e => e.candidate && pc2.addIceCandidate(e.candidate);
  pc2.onicecandidate = e => e.candidate && pc1.addIceCandidate(e.candidate);
  const dc = pc1.createDataChannel("test");
  pc2.ondatachannel = e => {
    e.channel.onmessage = m => out("datachannel received " + m.data);
  };
  dc.onopen = () => { out("datachannel open"); dc.send("ping"); };
  dc.onerror = e => out("datachannel error " + (e.message || e));
  dc.onclose = () => out("datachannel closed");
  const remote = document.getElementById("remote");
  pc2.ontrack = e => { remote.srcObject = e.streams[0]; };
  if (stream) stream.getTracks().forEach(t => pc1.addTrack(t, stream));
  const offer = await pc1.createOffer();
  out("offer has data section " + /m=application/.test(offer.sdp));
  await pc1.setLocalDescription(offer);
  await pc2.setRemoteDescription(offer);
  const answer = await pc2.createAnswer();
  await pc2.setLocalDescription(answer);
  await pc1.setRemoteDescription(answer);
  for (let i = 0; i < 40 && pc1.iceConnectionState != "connected" &&
       pc1.iceConnectionState != "completed"; i++)
    await new Promise(r => setTimeout(r, 250));
  out("ice " + pc1.iceConnectionState);
  for (let i = 0; i < 40 && dc.readyState != "open"; i++)
    await new Promise(r => setTimeout(r, 250));
  out("datachannel state " + dc.readyState);
  if (stream && stream.getVideoTracks().length) {
    for (let i = 0; i < 60 && !remote.videoWidth; i++)
      await new Promise(r => setTimeout(r, 250));
    out("remote video " + remote.videoWidth + "x" + remote.videoHeight);
    const rs = remote.srcObject;
    out("remote tracks video " + (rs ? rs.getVideoTracks().length : -1) +
        " audio " + (rs ? rs.getAudioTracks().length : -1) +
        " readyState " + remote.readyState + " paused " + remote.paused +
        " time " + remote.currentTime.toFixed(2));
  }
  out("done");
}
run().catch(e => out("error " + e.name + " " + e.message));
</script>"""


# /audio: plays a short tone through Web Audio (an audio output stream).
AUDIO_PAGE = """<!doctype html><title>Audio test</title><pre id=log></pre><script>
function out(t) { document.getElementById("log").textContent += t + "\\n";
  new Image().src = "/result?r=" + encodeURIComponent(t); }
try {
  const ctx = new AudioContext();
  const osc = ctx.createOscillator(); osc.connect(ctx.destination); osc.start();
  out("audiocontext state " + ctx.state + " rate " + ctx.sampleRate);
  setTimeout(() => { out("audiocontext time " + ctx.currentTime.toFixed(2) + " state " + ctx.state); osc.stop(); }, 3000);
} catch (e) { out("audio error " + e.name + " " + e.message); }
</script>"""


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
        elif url.path == "/audio":
            self.send(AUDIO_PAGE.encode(), "text/html; charset=utf-8")
        elif url.path == "/webrtc":
            self.send(WEBRTC_PAGE.encode(), "text/html; charset=utf-8")
        elif url.path == "/result":
            log("webrtc " + urllib.parse.parse_qs(url.query).get("r", [""])[0])
            self.send(b"ok", "text/plain")
        else:
            self.send_error(404)

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
