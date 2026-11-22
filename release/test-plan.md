# Test plan: Ageku

Primary target: **Haiku R1/beta6 x86_64** (the
`.hpkg` built in the beta6 VM). Secondary check: **Renku OS** x86_64 (the same
`.hpkg`; record anything that differs, don't block on it unless it crashes).

`{p}` below is the platform name (`haiku`, `renku`); type it literally so each
platform's evidence differs. Name UI elements by their labels.

## Fixtures

- **HTTP fixture** on the host (`release/fixture/serve.py`):

      HOSTIP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
      python3 -I release/fixture/serve.py 8765 dist/$V/evidence/{p}-form.log {p} &

  Guest URL: `http://$HOSTIP:8765/`. Prove it first from the host:
  `curl -s "http://$HOSTIP:8765/submit?q=probe"` then `grep 'q=probe' dist/$V/evidence/{p}-form.log`.
- **HTTPS**: `https://example.com/` (needs the guest's network; it checks NSS and
  the certificate store, not the fixture).
- **Media**: a short WebM (VP8/Vorbis) and an MP3 copied into the guest
  (`/boot/home/Desktop/test.webm`, `test.mp3`).
- **WebGL**: `https://get.webgl.org/` (needs the optional `mesa` package).

## Fresh state

Before each run, quit Ageku and remove its profile and caches:

    rm -rf /boot/home/config/settings/Ageku
    pkgman uninstall -y ageku 2>/dev/null; pkgman install -y ./ageku-$V-1-x86_64.hpkg


## Standard checks (release-test.md)

install, attrs (`catattr BEOS:APP_SIG /boot/system/apps/Ageku/ageku` ->
`application/x-vnd.Ageku`, Tracker shows the vector icon), launch from the
Deskbar entry "Ageku", log-clean (no crash dialog, no `debug_server` report),
quit with Command+Q.

## Feature checks

### page-load
Steps: launch; type `http://$HOSTIP:8765/` in the address bar, press Enter.
PASS when: OCR of the window shows "Ageku test page {p}" (save to
`{p}-page-load.txt`) and the window title starts with "Ageku test page".

### https
Steps: open `https://example.com/`.
PASS when: OCR shows "Example Domain" (`{p}-https.txt`) and no certificate error page.

### form-input
Steps: on the fixture page click the text field, type `hello from {p}`, click "Send".
PASS when: `{p}-form.log` has `q=hello+from+{p}` and the page shows "Got: hello from {p}".
Also type a few non-ASCII characters (ä, é, ß) with the keyboard and see them appear (IME is basic).

### shortcuts
Steps: Command+T (new tab), Command+W (close it), Command+L (focus address bar),
Command+F (find bar), Command+C / Command+V in the text field, Command+R (reload).
PASS when: each does what it says; write `PASS new-tab PASS close-tab PASS find`
(and the others) to `{p}-shortcuts.txt` only after seeing each on screen.

### download
Steps: on the fixture page click "sample.zip"; accept the download.
PASS when: the file is in `/boot/home/Downloads` (or the chosen folder) and
`catattr BEOS:TYPE <file>` prints `application/zip` (`{p}-download.txt`).

### single-launch
Steps: with Ageku running, run `open http://$HOSTIP:8765/` in Terminal, then
drop an `.html` file from Tracker onto the Ageku Deskbar entry/icon.
PASS when: both open in the running instance (new tab or window) and
`roster | grep -c x-vnd.Ageku` (or `ps | grep -c /ageku`) shows one team;
write `teams=1` to `{p}-single-launch.txt`.

## Further checks (record the result in the notes; not gated)

- **Window**: resize, maximize (Zoom), minimize via Deskbar, move between workspaces;
  menus and native-themed controls (buttons, check boxes, menus, scrollbars) look like Haiku.
- **Notifications**: `https://www.bennish.net/web-notifications.html` -> a Haiku
  notification appears.
- **Drag and drop**: drag a link from a page to the Desktop; drag an image from Tracker into a page.
- **Printing to PDF**: File > Print > "Save to PDF" writes a readable PDF.
- **Video/audio**: play `test.webm` and `test.mp3` (file:// URL); sound comes out
  (media kit); seek and pause work. With `ffmpeg6` or `ffmpeg8` installed, an
  H.264/AAC `.mp4` plays too; without it, the page must report the format as
  unsupported, not crash.
- **WebGL**: get.webgl.org shows the spinning cube (software rendering through OSMesa;
  without `mesa` installed the page must say WebGL is unavailable, not crash).
- **Quit and session restore**: open three tabs, Command+Q, relaunch; with
  "Restore previous session" (or History > Restore Previous Session) the tabs come back.
- **Single launch from another app**: click an http link in another app
  (e.g. a link in StyledEdit/Mail) with Ageku set as the preferred
  `text/html` app (FileTypes) -> it opens in the running instance.
- **Renku**: install the same `.hpkg` on Renku x86_64 and repeat page-load, https and
  form-input; note differences.
