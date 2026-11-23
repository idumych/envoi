#!/bin/sh
# smoke-test.sh: run on the HOST. It starts the browser in the Haiku build VM,
# takes screenshots, loads a local test page, collects logs and crash reports,
# then quits the app.
#
# Usage:
#   packaging/haiku/smoke-test.sh [APP_PATH] [OUT_DIR]
#
#   APP_PATH  browser binary in the VM
#             (default /boot/home/work/envoi/obj/dist/bin/envoi)
#   OUT_DIR   host directory for results (default ./smoke-<date>)
#
# Environment:
#   VM=basilisk-haiku          ssh host of the VM
#   VMDIR=~/VMs/basilisk-haiku QEMU VM dir (for screenshots)
#   APP_NAME=<binary name>     name `hey` uses to quit the app: Haiku registers the
#                              app under its file name (envoi, not Envoi)
#   APP_ARGS=...               default: -profile /boot/home/work/smoke-profile -no-remote
#   MOZLOG=...                 MOZ_LOG value (default: widget/gfx at level 4)
#   WAIT_START=25              seconds before the first screenshot
#   WAIT_PAGE=15               seconds after opening the test page
#   NO_PAGE=1                  skip the test page step
#
# Exit status: 0 = the app ran and quit, 2 = it crashed (debug_server report
# collected), 3 = it exited by itself early, 4 = it didn't quit and was killed.
#
# Example dry run with WebPositive in place of the browser:
#   APP_NAME=WebPositive APP_ARGS= sh packaging/haiku/smoke-test.sh /boot/system/apps/WebPositive

set -u
VM=${VM:-basilisk-haiku}
VMDIR=${VMDIR:-$HOME/VMs/basilisk-haiku}
QEMUVM=${QEMUVM:-/home/ian/.claude/skills/beos-app-platforms/scripts/qemu-vm.sh}
APP=${1:-/boot/home/work/envoi/obj/dist/bin/envoi}
OUT=${2:-./smoke-$(date +%Y%m%d-%H%M%S)}
APP_NAME=${APP_NAME:-$(basename "$APP")}
APP_ARGS=${APP_ARGS--profile /boot/home/work/smoke-profile -no-remote}
PROFILE=$(printf '%s\n' "$APP_ARGS" | sed -n 's/.*\(^\| \)-profile \([^ ]*\).*/\2/p')
MOZLOG=${MOZLOG:-Widget:4,WidgetPopup:4,gfx2d:4,nsHaikuWidgets:5,sync}
WAIT_START=${WAIT_START:-25}
WAIT_PAGE=${WAIT_PAGE:-15}
SMOKE=/boot/home/work/smoke            # scratch dir in the VM
EXE=$(basename "$APP")

mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
log() { printf '[smoke] %s\n' "$*" | tee -a "$OUT/smoke.txt"; }
vm() { ssh -o ConnectTimeout=10 "$VM" "$@"; }
# The headless VM's screen blanker turns the screen black: move the pointer
# (to an empty corner) to wake it before each screenshot.
wake() { DIR="$VMDIR" sh "$QEMUVM" move 4 790 >/dev/null 2>&1; DIR="$VMDIR" sh "$QEMUVM" move 6 792 >/dev/null 2>&1; sleep 2; }
shot() { wake; DIR="$VMDIR" sh "$QEMUVM" shot "$OUT/$1" >/dev/null 2>&1 && log "screenshot $OUT/$1.png" || log "screenshot $1 FAILED"; }

# Is the team still alive? (On Haiku the PID of the launched process is its team ID.)
alive() { vm "kill -0 $TEAM 2>/dev/null"; }

# Has debug_server caught the team? A crashed app stays alive (held by
# debug_server, which shows its alert or writes a report) and looks hung,
# so look at syslog and for a new report on the Desktop.
crashed() {
	vm "tail -n 400 /var/log/syslog | grep -E 'debug_server.*(team|Team)[^0-9]*$TEAM\b|$EXE.*(entered the debugger|crashed)|team $TEAM.*(Segment violation|General protection|Unhandled)' >/dev/null 2>&1 \
	    || find /boot/home/Desktop -maxdepth 1 -name '*.report' -newer $SMOKE/start.marker 2>/dev/null | grep -q ."
}

collect() {
	log "collecting logs into $OUT"
	vm "cat $SMOKE/app.log" > "$OUT/app.log" 2>/dev/null
	vm "tail -n 300 /var/log/syslog" > "$OUT/syslog-tail.txt" 2>/dev/null
	vm "find /boot/home/Desktop -maxdepth 1 -name '*.report' -newer $SMOKE/start.marker 2>/dev/null" > "$OUT/reports.txt" 2>/dev/null
	for r in $(cat "$OUT/reports.txt"); do
		vm "cat '$r'" > "$OUT/$(basename "$r")" 2>/dev/null && log "debug report: $OUT/$(basename "$r")"
	done
	vm "ps -a $TEAM" > "$OUT/threads.txt" 2>/dev/null || true
	log "app.log tail:"; tail -n 15 "$OUT/app.log" | sed 's/^/    /' | tee -a "$OUT/smoke.txt"
}

save_report() {
	# Ask Debugger to write a report for a team held by debug_server, then kill it.
	vm "Debugger --save-report=$SMOKE/crash-$TEAM.report --team $TEAM >/dev/null 2>&1; sleep 5; cat $SMOKE/crash-$TEAM.report" > "$OUT/crash-$TEAM.report" 2>/dev/null
	[ -s "$OUT/crash-$TEAM.report" ] && log "crash report: $OUT/crash-$TEAM.report" || log "no Debugger report (see syslog-tail.txt)"
}

finish() {	# finish STATUS
	collect
	vm "S=/boot/home/config/settings/system/debug_server; if [ -f \$S/settings.smoke-backup ]; then mv \$S/settings.smoke-backup \$S/settings; else rm -f \$S/settings; fi"
	if alive; then
		log "killing team $TEAM"
		vm "kill $TEAM; sleep 2; kill -0 $TEAM 2>/dev/null && kill -9 $TEAM"
	fi
	log "result: $1 (see $OUT)"
	exit "$1"
}

# --- 1. test page and debug_server settings in the VM ---------------------------
log "app: $APP  out: $OUT"
vm "test -x '$APP'" || { log "no executable $APP in the VM"; exit 1; }
vm "mkdir -p $SMOKE"
if command -v magick >/dev/null; then
	magick -size 160x100 gradient:'#3060c0-#f0c040' -gravity center -pointsize 20 \
		-fill white -annotate 0 'image OK' "$OUT/test.png" 2>/dev/null &&
		scp -q "$OUT/test.png" "$VM:$SMOKE/test.png"
fi
vm "cat > $SMOKE/test.html" <<'EOF'
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Smoke test page</title>
<style>
 body { font-family: sans-serif; margin: 20px; }
 #scroll { width: 300px; height: 120px; overflow: auto; border: 2px solid #448; }
 #scroll p { margin: 4px; }
 .box { display: inline-block; width: 60px; height: 40px; margin: 4px; }
</style></head>
<body>
<h1>Smoke test: Ünïcödé text, <em>italic</em>, <b>bold</b></h1>
<p>If you can read this, layout and font rendering work.</p>
<form onsubmit="document.getElementById('out').textContent = 'submitted: ' + this.q.value; return false;">
 <input name="q" value="type here" autofocus>
 <label><input type="checkbox" id="cb" checked> checkbox</label>
 <select><option>one</option><option>two</option></select>
 <button type="submit">Submit</button>
</form>
<p id="out">(not submitted)</p>
<div id="scroll">
 <p>Scrollable line 1</p><p>line 2</p><p>line 3</p><p>line 4</p><p>line 5</p>
 <p>line 6</p><p>line 7</p><p>line 8</p><p>line 9</p><p>line 10 (end)</p>
</div>
<p><img src="test.png" alt="[image missing]" width="160" height="100">
 <span class="box" style="background:red"></span><span class="box" style="background:#0a0"></span><span class="box" style="background:blue"></span></p>
<p id="js">JavaScript: not run</p>
<script>document.getElementById('js').textContent = 'JavaScript: OK, ' + navigator.userAgent;</script>
</body></html>
EOF
# Make debug_server write a report instead of only showing an alert for this
# executable. The settings file is per user; keep a backup of an existing one.
vm "S=/boot/home/config/settings/system/debug_server; mkdir -p \$S; \
    if [ -f \$S/settings ] && ! grep -q 'smoke-test' \$S/settings; then cp \$S/settings \$S/settings.smoke-backup; fi; \
    printf '# smoke-test\nexecutable_actions {\n\t%s report\n}\n' '$EXE' > \$S/settings"

# --- 2. start the app detached ----------------------------------------------------
vm "rm -rf /boot/home/work/smoke-profile; mkdir -p /boot/home/work/smoke-profile"
# Safe first-run prefs: no e10s, no GL layers, no default-browser or crash prompts.
vm "cat > /boot/home/work/smoke-profile/user.js" <<'EOF'
user_pref("browser.tabs.remote.autostart", false);
user_pref("browser.tabs.remote.autostart.2", false);
user_pref("layers.acceleration.disabled", true);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("toolkit.startup.max_resumed_crashes", -1);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("app.update.enabled", false);
EOF
vm "touch $SMOKE/start.marker"	# only debug reports newer than this count
START=$(date +%s)
TEAM=$(vm "cd $SMOKE; MOZ_LOG='$MOZLOG' nohup '$APP' $APP_ARGS > $SMOKE/app.log 2>&1 < /dev/null & echo \$!")
case $TEAM in ''|*[!0-9]*) log "could not start the app: $TEAM"; exit 1;; esac
log "started team $TEAM"

i=0
while [ $i -lt "$WAIT_START" ]; do
	sleep 5; i=$((i + 5))
	if crashed; then log "CRASH during startup after ${i}s"; shot 01-crash; save_report; finish 2; fi
	if ! alive; then log "app exited by itself after ${i}s"; shot 01-exited; finish 3; fi
done
shot 01-startup

# --- 3. load the test page ------------------------------------------------------
if [ -z "${NO_PAGE:-}" ]; then
	# A second invocation hands the URL to the running instance. (A Gecko app
	# started with -no-remote can't do that, so open the page in a new tab via
	# -new-tab without -no-remote, using the same profile.)
	if [ -n "$PROFILE" ]; then
		vm "cd $SMOKE; '$APP' -profile $PROFILE -new-tab file://$SMOKE/test.html >> $SMOKE/app2.log 2>&1 < /dev/null &" || true
	else
		vm "cd $SMOKE; '$APP' file://$SMOKE/test.html >> $SMOKE/app2.log 2>&1 < /dev/null &" || true
	fi
	log "opened file://$SMOKE/test.html"
	i=0
	while [ $i -lt "$WAIT_PAGE" ]; do
		sleep 5; i=$((i + 5))
		if crashed; then log "CRASH while loading the test page"; shot 02-crash; save_report; finish 2; fi
		if ! alive; then log "app exited while loading the test page"; shot 02-exited; finish 3; fi
	done
	shot 02-testpage
fi

# --- 4. quit cleanly -------------------------------------------------------------
log "quitting with: hey $APP_NAME quit"
vm "hey '$APP_NAME' quit" > "$OUT/hey.txt" 2>&1 || true
i=0
while alive && [ $i -lt 20 ]; do sleep 2; i=$((i + 2)); done
if alive; then
	if crashed; then log "CRASH on quit"; save_report; finish 2; fi
	log "did not quit within 20s"; finish 4
fi
log "quit OK after $(( $(date +%s) - START ))s total"
finish 0
