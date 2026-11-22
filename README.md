# Envoi

**Envoi** (the closing stanza that sends a poem on its way; also *envoy*, a messenger) is a web browser for
[Haiku](https://www.haiku-os.org/) and [Renku OS](https://github.com/RenkuOS/Source), with a
native Haiku user interface. It's an independent community project, built on the Unified XUL
Platform (UXP) with the Haiku engine work from [idumych/uxp-haiku](https://github.com/idumych/uxp-haiku)
(branch `haiku-envoi`), which is the `platform` submodule here.

Envoi is not endorsed by, or affiliated with, any other browser project. Please report problems
here, not to any upstream project.

**Status:** early. Envoi builds in a Haiku R1/beta6 VM, starts, draws a native window, renders
pages and runs under its own name, icon and app signature, with its own branding
(`palemoon/branding/envoi`). Not yet packaged or released. See [PLAN-HAIKU.md](PLAN-HAIKU.md).

## Screenshots

![Envoi on Haiku R1/beta6 showing https://www.haiku-os.org](docs/screenshots/haiku-https.png)

Envoi on Haiku R1/beta6 (x86_64), loading an HTTPS site.

## Licence

MPL 2.0 (see [LICENSE](LICENSE)); some bundled components carry other licences. Read
[TRADEMARK](TRADEMARK) for the trademark notice that comes with the source.
