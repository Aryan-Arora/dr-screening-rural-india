#!/bin/bash
# Downloads DDR's class-5 ("ungradable") images -- excluded from Module
# 3's training subset by ddr_selection.txt but real, labeled ground
# truth for image QUALITY, not DR severity. Same per-file download
# pattern as download_ddr_subset.sh, same disk-safety floor.
#
# NOT YET RUN -- part of the module1 validation draft pending review,
# see docs/module1_quality_validation_plan.md. Queued behind Module 3's
# (and Module 7/8's, if approved) training -- disk + CPU contention.
export PATH="$HOME/Library/Python/3.13/bin:$PATH"
cd "$(dirname "$0")"

DATASET="samriddhibagchi/ddr-dataset-credits-to-authors"
MIN_FREE_GB=3
OUT=images_ddr_ungradable

mkdir -p "$OUT"

free_gb() {
  df -g / | tail -1 | awk '{print $4}'
}

# Build the ungradable file list fresh from the label files already on
# disk (same files download_ddr_subset.sh used, class==5 this time).
python3 - <<'PYEOF'
rows = []
for split, fn in [("train","ddr_labels/train.txt"), ("valid","ddr_labels/valid.txt"), ("test","ddr_labels/test.txt")]:
    with open(fn) as f:
        for line in f:
            name, cls = line.strip().split()
            if int(cls) == 5:
                rows.append((name, split))
with open("ddr_ungradable_selection.txt", "w") as out:
    for name, split in rows:
        out.write(f"{name} {split}\n")
print(f"selected {len(rows)} ungradable images")
PYEOF

total=$(wc -l < ddr_ungradable_selection.txt)
n=0
while read -r name split; do
  n=$((n+1))
  dest="$OUT/ddr_${name}"
  if [ -f "$dest" ]; then continue; fi
  fg=$(free_gb)
  if [ "$fg" -lt "$MIN_FREE_GB" ]; then
    echo "ABORT: free space ${fg}GB < ${MIN_FREE_GB}GB, stopping at $n/$total" >> download_ddr_ungradable.log
    exit 1
  fi
  kaggle datasets download -d "$DATASET" -f "DDR-dataset/DR_grading/${split}/${name}" -p "$OUT" --force -q >>download_ddr_ungradable.log 2>&1
  srcname="$OUT/${name}"
  if [ -f "$srcname" ] && [ "$srcname" != "$dest" ]; then mv "$srcname" "$dest"; fi
  if [ $((n % 100)) -eq 0 ]; then
    echo "$(date +%H:%M:%S) progress: $n/$total" >> download_ddr_ungradable.log
  fi
done < ddr_ungradable_selection.txt

echo "$(date +%H:%M:%S) done: $n/$total" >> download_ddr_ungradable.log
