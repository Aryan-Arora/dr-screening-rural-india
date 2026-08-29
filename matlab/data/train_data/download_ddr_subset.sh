#!/bin/bash
# Downloads the curated DDR subset (ddr_selection.txt: filename class split)
# from the Kaggle mirror samriddhibagchi/ddr-dataset-credits-to-authors,
# one file at a time via `kaggle datasets download -f` (same pattern as
# download_eyepacs.sh). Disk-space-aware: aborts before it would push free
# space below MIN_FREE_GB, rather than risk a repeat of the ENOSPC crash
# hit earlier in this project.
export PATH="$HOME/Library/Python/3.13/bin:$PATH"
cd "$(dirname "$0")"

DATASET="samriddhibagchi/ddr-dataset-credits-to-authors"
SELECTION="ddr_selection.txt"
MIN_FREE_GB=3

mkdir -p images_ddr/{0,1,2,3,4}

free_gb() {
  df -g / | tail -1 | awk '{print $4}'
}

total=$(wc -l < "$SELECTION")
n=0
while read -r name cls split; do
  n=$((n+1))
  dest="images_ddr/${cls}/ddr_${name}"
  if [ -f "$dest" ]; then
    continue
  fi
  fg=$(free_gb)
  if [ "$fg" -lt "$MIN_FREE_GB" ]; then
    echo "ABORT: free space ${fg}GB < ${MIN_FREE_GB}GB minimum, stopping at $n/$total" >> download_ddr.log
    exit 1
  fi
  attempt=0
  until kaggle datasets download -d "$DATASET" \
      -f "DDR-dataset/DR_grading/${split}/${name}" \
      -p "images_ddr/${cls}" --force -q >>download_ddr.log 2>&1; do
    attempt=$((attempt+1))
    if [ $attempt -ge 3 ]; then
      echo "FAILED: $name" >> failed_ddr.log
      break
    fi
  done
  # kaggle CLI saves under the leaf filename directly since -f targets one file
  srcname="images_ddr/${cls}/${name}"
  if [ -f "$srcname" ] && [ "$srcname" != "$dest" ]; then
    mv "$srcname" "$dest"
  fi
  if [ $((n % 100)) -eq 0 ]; then
    echo "$(date +%H:%M:%S) progress: $n/$total, free=${fg}GB" >> download_ddr.log
  fi
done < "$SELECTION"

echo "$(date +%H:%M:%S) DDR subset download complete: $n/$total attempted" >> download_ddr.log
