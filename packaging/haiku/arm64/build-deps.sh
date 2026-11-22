#!/bin/sh
# build-deps.sh: prepare the Renku OS arm64 sysroot for cross-building Envoi on Linux.
#
#   sh packaging/haiku/arm64/build-deps.sh [WORKDIR]     (default ~/.cache/envoi-arm64)
#
# Needs the Haiku arm64 cross tools (aarch64-unknown-haiku-gcc, package, rc, xres,
# addattr), set up by beos-app-platforms' make-sysroot.sh: source its env.sh first.
# Makes WORKDIR/sysroot from that sysroot plus:
#   - Renku's arm64 ports (renkuosports/arm64): libffi, fontconfig, freetype, zlib,
#     libiconv, libjpeg_turbo, sqlite, libxml2 and what they need, with _devel parts;
#   - NSPR 4.39, NSS 3.133 and libevent 2.1.13, which Renku arm64 doesn't package:
#     cross-built from HaikuPorts' versions, checksums and patchsets, plus
#     patches/ (aarch64 for NSPR's and NSS's Haiku config; NSPR's OS_ARCH when
#     cross-compiling, so its Haiku files build). Envoi's arm64 package
#     ships these libraries in apps/Envoi/lib.
# Then rewrites the pkg-config files to point into the sysroot.
set -eu
W=${1:-$HOME/.cache/envoi-arm64}
HERE=$(cd "$(dirname "$0")" && pwd)
: "${HAIKU_ARM64_SYSROOT:?source the Haiku arm64 cross tools env.sh first}"
REPO=https://renkuos.freemyip.com/repo/renkuosports/arm64
HP=https://raw.githubusercontent.com/haikuports/haikuports/master
SR=$W/sysroot
D=$W/deps
mkdir -p "$W/pkgs" "$W/src" "$W/recipes"

# 1. Sysroot: a private copy of the cross tools' sysroot plus Renku's arm64 ports.
rm -rf "$SR" "$D"
cp -a "$HAIKU_ARM64_SYSROOT" "$SR"
curl -fsS -m 120 "$REPO/" | grep -o 'packages/[^"]*\.hpkg' | sed 's#packages/##' > "$W/ports.txt"
for p in libffi fontconfig freetype zlib libiconv libjpeg_turbo expat libpng16 bzip2 \
		brotli sqlite libxml2; do
	for n in "$p" "${p}_devel"; do
		f=$(grep -E "^${n}-[0-9]" "$W/ports.txt" | head -1)
		[ -n "$f" ] || { echo "build-deps: $n not in $REPO" >&2; exit 1; }
		[ -f "$W/pkgs/$f" ] || curl -fsS -m 600 -o "$W/pkgs/$f" "$REPO/packages/$f"
		package extract -C "$SR" "$W/pkgs/$f"
	done
done

# Cross flags: the kit headers without os/drivers/* (pcmcia/memory.h would shadow
# <memory.h>), the C library last.
XC=$(echo "$HAIKU_CROSS_CFLAGS" | sed "s#$HAIKU_ARM64_SYSROOT#$SR#g" | tr ' ' '\n' \
	| grep -v '/os/drivers' | tr '\n' ' ')
XL=$(echo "$HAIKU_CROSS_LDFLAGS" | sed "s#$HAIKU_ARM64_SYSROOT#$SR#g")
CCX="aarch64-unknown-haiku-gcc --sysroot=$SR -B$SR/develop/lib"
G="git -c user.name=build -c user.email=build@localhost"

fetch() {	# fetch URL SHA256 -> unpacked source dir in $W/src
	f=$W/src/$(basename "$1")
	[ -f "$f" ] || curl -fsSL -m 900 -o "$f" "$1"
	echo "$2  $f" | sha256sum -c --quiet
}
patched() {	# patched DIR PATCHSET... : apply patches as commits in a fresh git repo
	dir=$1; shift
	(cd "$dir" && $G init -q . && git add -A >/dev/null && $G commit -qm base \
		&& for p in "$@"; do $G am -q --keep-cr "$p"; done)
}

# 2. NSPR 4.39
curl -fsS -m 60 -o "$W/recipes/nspr.patchset" "$HP/dev-libs/nspr/patches/nspr-4.39.patchset"
fetch https://ftp.mozilla.org/pub/mozilla.org/nspr/releases/v4.39/src/nspr-4.39.tar.gz \
	bbd02ee87a55676063a63e5bc819e0227de2666b47307b2a0134414cdf42368e
rm -rf "$W/src/nspr-4.39"; tar -xzf "$W/src/nspr-4.39.tar.gz" -C "$W/src"
patched "$W/src/nspr-4.39/nspr" "$W/recipes/nspr.patchset"
(cd "$W/src/nspr-4.39/nspr" && git apply "$HERE/patches/nspr-4.39-haiku-arm64.patch" \
	&& autoreconf -fi >/dev/null 2>&1 \
	&& CC=aarch64-unknown-haiku-gcc CXX=aarch64-unknown-haiku-g++ \
		CFLAGS="$XC -O2" CXXFLAGS="$XC -O2" LDFLAGS="$XL" HOST_CC=gcc HOST_CFLAGS=-O2 HOST_LDFLAGS= \
		./configure --host=aarch64-unknown-haiku --build=x86_64-pc-linux-gnu \
		--target=aarch64-unknown-haiku --prefix=/boot/system \
		--includedir=/boot/system/develop/headers/nspr --libdir=/boot/system/lib \
		--disable-debug --enable-optimize --enable-cplus --with-pthreads --enable-64bit \
		> "$W/nspr.log" 2>&1 \
	&& make -j"$(nproc)" >> "$W/nspr.log" 2>&1 && make DESTDIR="$D" install >> "$W/nspr.log" 2>&1)

# 3. libevent 2.1.13
curl -fsS -m 60 -o "$W/recipes/libevent.patchset" "$HP/dev-libs/libevent/patches/libevent-2.1.13.patchset"
fetch https://github.com/libevent/libevent/releases/download/release-2.1.13-stable/libevent-2.1.13-stable.tar.gz \
	f7e9383b8c0baa81b687e5b5eecc01beefaf1b19b64151d95ed61647fe7a315c
rm -rf "$W/src/libevent-2.1.13-stable"; tar -xzf "$W/src/libevent-2.1.13-stable.tar.gz" -C "$W/src"
patched "$W/src/libevent-2.1.13-stable" "$W/recipes/libevent.patchset"
(cd "$W/src/libevent-2.1.13-stable" && autoreconf -fi >/dev/null 2>&1 \
	&& CC="$CCX" CFLAGS="$XC -O2" CPPFLAGS="-D_BSD_SOURCE -DEV_ENABLE=0" LDFLAGS="$XL -lbsd -lnetwork" \
		./configure --host=aarch64-unknown-haiku --build=x86_64-pc-linux-gnu --prefix=/boot/system \
		--libdir=/boot/system/lib --includedir=/boot/system/develop/headers --disable-static \
		--disable-samples --disable-openssl --disable-libevent-regress > "$W/libevent.log" 2>&1 \
	&& make -j"$(nproc)" >> "$W/libevent.log" 2>&1 && make DESTDIR="$D" install >> "$W/libevent.log" 2>&1)

# 4. NSS 3.133 (coreconf; not parallel-safe)
curl -fsS -m 60 -o "$W/recipes/nss.patchset" "$HP/dev-libs/nss/patches/nss-3.133.patchset"
fetch https://ftp.mozilla.org/pub/mozilla.org/security/nss/releases/NSS_3_133_RTM/src/nss-3.133.tar.gz \
	4d752526b9846a1d962588cfbd09b7cc2a4f6a4effbd9157d58a30e8a2573065
rm -rf "$W/src/nss-3.133"; tar -xzf "$W/src/nss-3.133.tar.gz" -C "$W/src"
patched "$W/src/nss-3.133/nss" "$W/recipes/nss.patchset"
(cd "$W/src/nss-3.133/nss" && git apply "$HERE/patches/nss-3.133-haiku-arm64.patch")
T="OS_ARCH=Haiku OS_TARGET=Haiku OS_TEST=aarch64 OS_RELEASE=1"
(cd "$W/src/nss-3.133/nss" \
	&& export NSDISTMODE=copy FREEBL_NO_DEPEND=1 NSS_ENABLE_WERROR=0 NSS_DISABLE_GTESTS=1 USE_64=1 BUILD_OPT=1 \
	&& make -C coreconf/nsinstall program $T CC=gcc "OS_CFLAGS=-DLINUX -D_DEFAULT_SOURCE" LDFLAGS= \
		> "$W/nss.log" 2>&1 \
	&& for d in . lib/dbm; do
		make -j1 -C $d $T CROSS_COMPILE=1 "CC=$CCX" \
			"CCC=aarch64-unknown-haiku-g++ --sysroot=$SR -B$SR/develop/lib" \
			RANLIB=aarch64-unknown-haiku-ranlib NATIVE_CC=gcc NATIVE_FLAGS=-DLINUX NATIVE_LDFLAGS= \
			NSPR_INCLUDE_DIR="$D/boot/system/develop/headers/nspr" NSPR_LIB_DIR="$D/boot/system/lib" \
			"XCFLAGS=$XC" "LDFLAGS=$XL" >> "$W/nss.log" 2>&1 || exit 1
	done)
N=$W/src/nss-3.133/dist
mkdir -p "$D/boot/system/develop/headers/nss"
cp "$N"/Haiku1_PTH_64_OPT.OBJ/lib/*.so "$D/boot/system/lib/"
cp -r "$N"/public/nss/* "$D/boot/system/develop/headers/nss/"

# 5. Merge into the sysroot; pkg-config files point into it.
B=$D/boot/system
cp -a "$B"/lib/*.so* "$SR/lib/"
for f in "$B"/lib/*.so; do
	n=$(basename "$f"); [ -e "$SR/develop/lib/$n" ] || ln -s "../../lib/$n" "$SR/develop/lib/$n"
done
cp -a "$B"/develop/headers/* "$SR/develop/headers/"
for f in "$B"/lib/pkgconfig/*.pc; do sed "s#/boot/system#$SR#g" "$f" > "$SR/develop/lib/pkgconfig/$(basename "$f")"; done
sed -i "s#/packages/[^/ ]*/\.self#$SR#g" "$SR"/develop/lib/pkgconfig/*.pc
cat > "$SR/develop/lib/pkgconfig/nss.pc" <<EOF
prefix=$SR
libdir=$SR/develop/lib
includedir=$SR/develop/headers/nss
Name: NSS
Description: Network Security Services
Version: 3.133
Requires: nspr
Libs: -L\${libdir} -lssl3 -lsmime3 -lnss3 -lnssutil3
Cflags: -I\${includedir}
EOF
# The libraries the package ships in apps/Envoi/lib
mkdir -p "$W/bundle"
# (by soname, as the binaries' NEEDED entries name them)
for l in libnspr4.so libplc4.so libplds4.so libnss3.so libnssutil3.so libsmime3.so libssl3.so \
		libsoftokn3.so libfreebl3.so libnssckbi.so libnssdbm3.so libevent-2.1.so.7 \
		libevent_core-2.1.so.7 libevent_extra-2.1.so.7 libevent_pthreads-2.1.so.7; do
	cp -L "$B/lib/$l" "$W/bundle/"
done
ls "$W/bundle"
echo "build-deps: sysroot ready in $SR"
