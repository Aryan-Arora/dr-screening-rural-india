#!/bin/bash
cd /Users/aryanarora/Desktop/dr-screening-pipeline/matlab/data/train_data

echo "$(date): waiting for EyePACS download to complete..."
while [ ! -f download_eyepacs_stdout.log ] || ! grep -q "EYEPACS_DOWNLOAD_COMPLETE" download_eyepacs_stdout.log; do
  sleep 10
  free_kb=$(df -k / | tail -1 | awk '{print $4}')
  if [ "$free_kb" -lt 300000 ]; then
    echo "$(date): DISK CRITICALLY LOW ($((free_kb/1024))MB free) -- stopping download"
    pkill -f download_eyepacs.sh
    pkill -f "kaggle datasets download"
    break
  fi
done
echo "$(date): download phase done."
for d in 0 1 2 3 4; do echo "class $d: $(find images/$d -name '*.png' -o -name '*.jpeg' 2>/dev/null | wc -l)"; done

echo "$(date): launching full training (all 3 backbones + ensemble) on combined APTOS+EyePACS dataset..."
/Applications/MATLAB_R2026a.app/bin/matlab -batch "run('/Users/aryanarora/Desktop/dr-screening-pipeline/matlab/scripts/train_module3_all.m')" \
  > /Users/aryanarora/Desktop/dr-screening-pipeline/matlab/data/train_data/full_training_v3.log 2>&1

echo "$(date): FULL TRAINING V3 PIPELINE COMPLETE"
