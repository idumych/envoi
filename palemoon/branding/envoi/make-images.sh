#!/bin/sh
# Draws Envoi's branding PNGs from the app icon (../../app/haiku/icon-preview.svg,
# made by make-icon.py). Needs rsvg-convert and ImageMagick. Run from this directory.
set -e
ICON=../../app/haiku/icon-preview.svg
for s in 16 32 48; do rsvg-convert -w $s -h $s $ICON -o default$s.png; done
rsvg-convert -w 128 -h 128 $ICON -o mozicon128.png
for s in 48 64; do rsvg-convert -w $s -h $s $ICON -o content/icon$s.png; done
rsvg-convert -w 192 -h 192 $ICON -o content/about-logo.png
rsvg-convert -w 384 -h 384 $ICON -o content/about-logo@2x.png
TMP=$(mktemp --suffix=.svg)
ICONDATA=$(base64 -w0 $ICON)
# About window: ink-blue paper, the icon, the name and its meaning.
cat > "$TMP" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="700" height="410">
<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#1d2a44"/><stop offset="1" stop-color="#0d1424"/></linearGradient></defs>
<rect width="700" height="410" fill="url(#bg)"/>
<image x="206" y="28" width="104" height="104" xlink:href="data:image/svg+xml;base64,$ICONDATA"/>
<text x="330" y="96" font-family="DejaVu Serif, serif" font-size="52" fill="#f6efdc">Envoi</text>
<text x="332" y="124" font-family="DejaVu Sans, sans-serif" font-size="16" fill="#c9b98f">the closing verse that sends a poem on</text>
</svg>
SVG
rsvg-convert "$TMP" -o content/about-background.png
rsvg-convert -w 160 -h 160 $ICON | magick -size 300x236 xc:"#1d2a44" - -gravity center -composite content/about.png
rm "$TMP"
