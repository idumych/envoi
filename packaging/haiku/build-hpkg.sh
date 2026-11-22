#!/bin/sh
# Build ageku-<VERSION>-<REVISION>-<arch>.hpkg from a packaged objdir.
#
#   MOZ_DISABLE_PRECOMPILED_STARTUPCACHE=1 make -C OBJDIR package   # stages OBJDIR/dist/ageku
#   packaging/haiku/build-hpkg.sh [OBJDIR] [OUTDIR] [ARCH]
#
# ARCH is x86_64 (default; run on Haiku) or arm64 (Renku OS; run on the Linux
# build host with the cross tools' package and addattr on PATH, see
# packaging/haiku/build-arm64.md). Installs to apps/Ageku with a Deskbar link
# and bin/ageku. Version and requirements come from haiku-app.env.
set -e

here=$(cd "$(dirname "$0")" && pwd)
top=$(cd "$here/../.." && pwd)
. "$top/haiku-app.env"
objdir=${1:-${MOZ_OBJDIR:-$top/../obj}}
outdir=${2:-.}
arch=${3:-x86_64}
appdir="$objdir/dist/ageku"
requires=$HPKG_REQUIRES_EXTRA
[ "$arch" = arm64 ] && requires=${HPKG_REQUIRES_ARM64-$HPKG_REQUIRES_EXTRA}

if [ ! -x "$appdir/ageku" ]; then
	echo "build-hpkg.sh: $appdir/ageku not found; run make package first" >&2
	exit 1
fi

stage=$(mktemp -d "${TMPDIR:-/tmp}/ageku-hpkg.XXXXXX")
trap 'rm -rf "$stage"' EXIT

mkdir -p "$stage/apps/Ageku" "$stage/bin" "$stage/data/deskbar/menu/Applications"
cp -a "$appdir/." "$stage/apps/Ageku/"
ln -s ../../../../apps/Ageku/ageku "$stage/data/deskbar/menu/Applications/Ageku"
ln -s ../apps/Ageku/ageku "$stage/bin/ageku"

if [ "$arch" = x86_64 ]; then
	# Tracker reads the signature and icon attached at link time.
	mimeset -f "$stage/apps/Ageku/ageku" "$stage/apps/Ageku/ageku-bin" 2>/dev/null || true
else
	# The host's mimeset doesn't know arm64 binaries: write the attributes.
	for f in ageku ageku-bin; do
		addattr -t mime BEOS:TYPE application/x-vnd.Be-elfexecutable "$stage/apps/Ageku/$f"
		addattr -t mime BEOS:APP_SIG "$APP_SIG" "$stage/apps/Ageku/$f"
	done
fi

# Description: one paragraph; quotes and sed specials escaped.
description=$(tr '\n' ' ' < "$here/description.txt" | sed -e 's/ *$//' \
	-e 's/["\\]/\\&/g' -e 's/[&|]/\\&/g')
req=$(for r in $requires; do printf '\t%s\\n' "$r"; done)
sed -e "s/@VERSION@/$VERSION/g" -e "s/@REVISION@/$REVISION/g" -e "s/@ARCH@/$arch/" \
	-e "s|@DESCRIPTION@|$description|" -e "s|^@REQUIRES@\$|$req|" \
	"$here/PackageInfo.in" > "$stage/.PackageInfo"

mkdir -p "$outdir"
outdir=$(cd "$outdir" && pwd)
out="$outdir/$APP_CMD-$VERSION-$REVISION-$arch.hpkg"
rm -f "$out"
package create -C "$stage" -i "$stage/.PackageInfo" "$out"
echo "$out"
