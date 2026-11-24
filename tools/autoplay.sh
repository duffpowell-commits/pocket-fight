#!/bin/sh
# Plays the whole flow with the autoplay bot and saves screenshots to docs/renders/, plus a 15 s vertical (9:16)
# gameplay clip (gameplay.mp4 in the same folder; needs ffmpeg, which CI has).
# Usage: tools/autoplay.sh [shots_dir]   (needs godot + xvfb-run; CI runs this on every push)
set -e
SHOTS=${1:-$(pwd)/docs/renders}
XDG=$(mktemp -d)
CLIP=$(mktemp -d)
XDG_DATA_HOME=$XDG timeout 300 xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . \
  --rendering-driver opengl3 --resolution 540x960 -- --autoplay --shots="$SHOTS" --clip="$CLIP" 2>&1 | tee autoplay.log
rm -rf "$XDG"
if command -v ffmpeg >/dev/null && [ -f "$CLIP/fps.txt" ]; then
  ffmpeg -loglevel error -y -framerate "$(cat "$CLIP/fps.txt")" -i "$CLIP/f%04d.jpg" \
    -vf "fps=30,scale=720:1280:flags=lanczos,setsar=1" -c:v libx264 -pix_fmt yuv420p -crf 26 -movflags +faststart "$SHOTS/gameplay.mp4" \
    && echo "CLIP VIDEO $SHOTS/gameplay.mp4"
fi
rm -rf "$CLIP"
grep -q "^AUTOPLAY PASS" autoplay.log && ! grep -qE "^FAIL|^AUTOPLAY FAIL|SCRIPT ERROR" autoplay.log || { echo "autoplay failed"; exit 1; }
