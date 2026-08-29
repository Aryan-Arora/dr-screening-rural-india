#!/bin/bash
# Downloads the HRDC-style hypertensive-retinopathy dataset and sorts it
# into class-labeled subfolders ('0' non-hypertensive, '1' hypertensive)
# matching prepareHRDCDatastore.m's expected layout.
#
# NOT YET RUN -- part of the module7 draft pending review, see
# docs/module7_hypertensive_retinopathy_plan.md. Queued to run only
# after Module 3's multi-dataset training finishes (disk + CPU
# contention with that run).
set -e
cd "$(dirname "$0")"
export PATH="$HOME/Library/Python/3.13/bin:$PATH"

DATASET="harshwardhanfartale/hypertension-and-hypertensive-retinopathy-dataset"
OUT=hrdc_raw

mkdir -p "$OUT"
kaggle datasets download -d "$DATASET" -p "$OUT" --force
cd "$OUT"
unzip -q *.zip
rm -f *.zip

echo "Downloaded and extracted. Inspect the folder structure before writing"
echo "the label-sorting step below -- HRDC's actual layout (label CSV vs."
echo "class-named folders) needs confirming against the real download,"
echo "which wasn't done as part of this draft to avoid the disk usage"
echo "while Module 3's run is still using most of the free headroom."
