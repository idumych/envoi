# Envoi for Renku OS arm64

Envoi's arm64 package targets **Renku OS** (there is no Haiku R1/beta6 arm64 release). It is
cross-built on an x86_64 Linux host against Renku's arm64 packages and tested on Renku's arm64
image in QEMU.

## Needs

- The Haiku arm64 cross tools and a Renku arm64 sysroot (`aarch64-unknown-haiku-gcc`, and the
  host tools `package`, `rc`, `xres`, `addattr`), made by the beos-app-platforms skill's
  `make-sysroot.sh`; source its `env.sh`.
- Python 3.12 as `python3` on `PATH` (UXP's build doesn't run on 3.14), and `zip`.

## Build

    . ~/.cache/haiku-arm64/env.sh; unset CC CXX
    sh packaging/haiku/arm64/build-deps.sh ~/.cache/envoi-arm64
    export ENVOI_SR=~/.cache/envoi-arm64/sysroot ENVOI_ARM64_OBJ=~/.cache/envoi-arm64/obj
    MOZCONFIG=$PWD/packaging/haiku/arm64/mozconfig ./mach build
    make -C ~/.cache/envoi-arm64/obj package MOZ_DISABLE_PRECOMPILED_STARTUPCACHE=1
    ENVOI_ARM64_BUNDLE=~/.cache/envoi-arm64/bundle \
        sh packaging/haiku/build-hpkg.sh ~/.cache/envoi-arm64/obj dist arm64

`build-deps.sh` builds the sysroot: Renku's arm64 ports (libffi, fontconfig, freetype, zlib,
libiconv, libjpeg_turbo and what they need), plus NSPR 4.39, NSS 3.133 and libevent 2.1.13,
which Renku arm64 doesn't package. Those three are cross-built from HaikuPorts' sources and
patchsets plus `patches/` (aarch64 for NSPR's and NSS's Haiku configuration) and ship inside
the package, in `apps/Envoi/lib`.

## Notes

- `mozconfig` passes the Haiku kit headers with `-isystem`, inside `CC`/`CXX`: with `-I` they
  come before Gecko's own include paths and kit headers with common names shadow Gecko's;
  outside `CC`, some configure checks don't see them.
- The host's gold linker can't link aarch64: `--disable-gold`.
- Packaging skips the startup-cache precompilation (it runs the target's `xpcshell`): pass
  `MOZ_DISABLE_PRECOMPILED_STARTUPCACHE=1` on the `make` command line (in the environment,
  the Makefiles' empty value wins).
