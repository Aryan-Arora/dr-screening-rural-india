#!/bin/bash
cd /Users/aryanarora/Desktop/dr-screening-pipeline/matlab/data/train_data

echo "$(date): waiting for full dataset download to complete..."
while [ ! -f download_stdout4.log ] || ! grep -q "DOWNLOAD_COMPLETE" download_stdout4.log; do
  sleep 15
  free_kb=$(df -k / | tail -1 | awk '{print $4}')
  if [ "$free_kb" -lt 500000 ]; then
    echo "$(date): DISK CRITICALLY LOW ($((free_kb/1024))MB free) -- stopping download"
    pkill -f download_balanced.sh
    pkill -f "kaggle datasets download"
    break
  fi
done
echo "$(date): download phase done."
for d in 0 1 2 3 4; do echo "class $d: $(find images/$d -name '*.png' 2>/dev/null | wc -l)"; done

echo "$(date): regenerating APTOS-only symlink view with full dataset..."
rm -rf images_aptos_only
mkdir -p images_aptos_only/{0,1,2,3,4}
BASE="$(pwd)"
for c in 0 1 2 3 4; do
  find "$BASE/images/$c" -name "*.png" -exec ln -s {} "$BASE/images_aptos_only/$c/" \;
done
for d in 0 1 2 3 4; do echo "aptos_only class $d: $(find images_aptos_only/$d -name '*.png' | wc -l)"; done

echo "$(date): launching full training (all 3 backbones + ensemble) on full dataset..."
/Applications/MATLAB_R2026a.app/bin/matlab -batch "run('/Users/aryanarora/Desktop/dr-screening-pipeline/matlab/scripts/train_module3_aptos_only.m')" \
  > /Users/aryanarora/Desktop/dr-screening-pipeline/matlab/data/train_data/full_training_v5_full_dataset.log 2>&1

echo "$(date): FULL TRAINING V5 (FULL DATASET) COMPLETE"
