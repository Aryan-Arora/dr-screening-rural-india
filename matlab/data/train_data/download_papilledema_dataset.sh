#!/bin/bash
# Downloads the Papilledema/Pseudopapilledema/Normal dataset (already
# confirmed by direct download+inspection during planning: 295/295/779
# images, real folder names 'Papilledema'/'Pseudopapilledema'/'Normal').
#
# NOT YET RUN as part of the actual project pipeline -- part of the
# module9 draft pending review, see docs/module9_papilledema_plan.md.
set -e
cd "$(dirname "$0")"
export PATH="$HOME/Library/Python/3.13/bin:$PATH"

DATASET="shashwatwork/identification-of-pseudopapilledema"
OUT=images_papilledema

mkdir -p "$OUT"
kaggle datasets download -d "$DATASET" -p "$OUT" --force -q
cd "$OUT"
unzip -q *.zip
rm -f *.zip

echo "Expect 3 subfolders: Papilledema (295), Pseudopapilledema (295), Normal (779)"
for d in Papilledema Pseudopapilledema Normal; do
  echo "  $d: $(ls "$d" 2>/dev/null | wc -l)"
done
