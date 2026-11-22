# Envoi: plan

Envoi is a UXP-based web browser for Haiku R1/beta6 and Renku OS (x86_64), with a native
Haiku interface. It shares its engine work with the Basilisk port
([idumych/basilisk-haiku](https://github.com/idumych/basilisk-haiku)), which already runs on
Haiku: it builds, starts, draws a native window, renders pages, loads HTTPS sites and installs
from an `.hpkg`.

## Rules we follow (from the source's redistribution terms)

- **Own identity.** The source ships an unofficial branding ("New Moon") that may be used for
  unendorsed binaries, but only while a new product identity is established. Envoi replaces it
  with its own name, logo and icon as early as possible; until then, test builds may use it.
- **No implied relationship.** Envoi must not be presented as endorsed by, or related to, the
  project its source comes from, or that project's owners. Its README, About window, package
  description and release notes describe Envoi on its own terms.
- **No leftover marks.** The upstream product name and logo must not appear in Envoi builds:
  remove any remaining strings, images and icons (About window, crash/update text, help links,
  start page, default bookmarks, search plugins).
- **MPL.** Source changes stay public under the MPL; keep the LICENSE and TRADEMARK files.

## What carries over from the Basilisk port

| Layer | Source | Work for Envoi |
|---|---|---|
| Engine (UXP): build system, xpcom, ipc, js, native widget/haiku, gfx, media, netwerk, toolkit | uxp-haiku `haiku-all` | **Done:** merged onto this source's newer UXP pin (54 commits ahead) as `haiku-envoi`, with no conflicts. Needs a build to confirm. |
| App resources (signature, icon, file types) | `basilisk/app/haiku/` | Port to the app dir; signature `application/x-vnd.Envoi`; an HVIF icon of Envoi's own. |
| App build hooks, package manifest | `basilisk/app`, `basilisk/installer` | Port the Haiku cases (resource attach, system NSPR, shell-icon PNGs). |
| Front end: Command-key accel-click, theme fallbacks, Haiku prefs, Desktop downloads | `basilisk/base/content`, `components`, `themes` | Reapply the `MOZ_WIDGET_HAIKU` cases; this front end differs from Basilisk's, so review each hunk. |
| Shell service (default browser through BMimeType) | `basilisk/components/shell/nsHaikuShellService` | Port; register Envoi for text/html and http/https. |
| Packaging and release: build-hpkg.sh, PackageInfo, test plan, notes template | `packaging/haiku`, `release/`, `haiku-app.env` | Package `envoi`, app `Envoi`, `apps/Envoi`. |
| mozconfig, build guide, smoke test, milestone bar | Basilisk top level, `tools/` | Copy and rename. |

## Branding work

Done (first pass, 2026-11-22): `palemoon/branding/envoi` is the default branding; the program
is `envoi`; default bookmarks, first-run/update pages, error-page strings, the About dialog,
the binary licence text, search-plugin partner codes and upstream add-on install permissions
were replaced or removed. A sweep of the built app finds the upstream name only in code
comments, a sync-URL migration, a reader-mode domain list and the platform's build-instructions
link in about:license. Still open: the add-on catalogue and blocklist point at the upstream
add-ons site (`AM_DOMAIN` in `palemoon/app/profile/palemoon.js`); sync has no server.

1. A branding directory of Envoi's own (`branding/envoi`): name, wordmark, about-dialog art, and
   a vector icon (HVIF, via make-hvif-icon.py) that doesn't derive from any upstream logo.
   Theme it on the envoi: the closing stanza that sends a poem on its way.
2. Build with `--with-branding=<envoi branding dir>`.
3. Sweep the built app (omni.ja, chrome, locales, defaults) for the upstream name and logo,
   and remove what's left.

## Steps

1. Configure and build in the Haiku VM against `haiku-envoi`; fix what the newer UXP and this
   app layer break.
2. Envoi branding (above), then port the app layer.
3. Smoke test (window, test page, HTTPS), then an `.hpkg` that passes check-artifact.
4. Shared engine fixes go to uxp-haiku for both browsers (quit: fixed 2026-11-22):
   xpcshell on Haiku, input testing, video.
5. Release test plan, and publish only when a human says so.

## Lessons from Basilisk to apply from the start

- Build in a Haiku R1/beta6 VM with HaikuPorts packages; copy sources in as a tarball, then
  send diffs. Never rsync whole trees over QEMU's network.
- Haiku headers must be wrapped in `config/system-headers`, and forward-declared Be classes need
  default visibility, or libxul can't link against libbe (done in uxp-haiku).
- Classes derived from Be classes need `-frtti`, in files without Gecko polymorphic classes
  (done in uxp-haiku).
- Package with `MOZ_DISABLE_PRECOMPILED_STARTUPCACHE=1 make package` until xpcshell works.
