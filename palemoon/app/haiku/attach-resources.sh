#!/bin/sh
# Usage: attach-resources.sh <file.rsrc> <executable>
# Called by rules.mk as $(MOZ_POST_PROGRAM_COMMAND) right after linking.
set -e
xres -o "$2" "$1"
mimeset -f "$2"
