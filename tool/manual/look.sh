#!/bin/sh
# The simulator's screen as it is now (the app or not), small, for a quick look: look.sh <out.jpg> [width]
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
UDID=${MANUAL_UDID:-$(xcrun simctl list devices | sed -n 's/.*ICR Manual (\([0-9A-F-]*\)) (Booted).*/\1/p' | head -1)}
xcrun simctl io "$UDID" screenshot --type=png "$1.png" >/dev/null 2>&1
(cd "$HERE" && node -e "import('sharp').then(s=>s.default(process.argv[1]+'.png').resize({width:Number(process.argv[2]||402)}).jpeg({quality:78}).toFile(process.argv[1])).then(()=>require('fs').rmSync(process.argv[1]+'.png'))" "$1" "$2")
echo "$1"
