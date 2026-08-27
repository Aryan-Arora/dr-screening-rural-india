#!/bin/bash
cd /Users/aryanarora/Desktop/dr-screening-pipeline/matlab/data/train_data

echo "$(date): waiting for expanded download to complete..."
while [ ! -f download_stdout2.log ] || ! grep -q "DOWNLOAD_COMPLETE" download_stdout2.log; do
  sleep 10
  free_kb=$(df -k / | tail -1 | awk '{print $4}')
  if [ "$free_kb" -lt 300000 ]; then
    echo "$(date): DISK CRITICALLY LOW ($((free_kb/1024))MB free) -- stopping download to avoid filling disk"
    pkill -f download_balanced.sh
    pkill -f "kaggle datasets download"
    break
  fi
done
echo "$(date): download phase done. Image count: $(find images -name '*.png' | wc -l)"
for d in 0 1 2 3 4; do echo "class $d: $(find images/$d -name '*.png' | wc -l)"; done

echo "$(date): launching full training (all 3 backbones + ensemble)..."
/Applications/MATLAB_R2026a.app/bin/matlab -batch "run('/Users/aryanarora/Desktop/dr-screening-pipeline/matlab/scripts/train_module3_all.m')" \
  > /Users/aryanarora/Desktop/dr-screening-pipeline/matlab/data/train_data/full_training_v2.log 2>&1

echo "$(date): FULL TRAINING V2 PIPELINE COMPLETE"
