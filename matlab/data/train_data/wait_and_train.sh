#!/bin/bash
cd /Users/aryanarora/Desktop/dr-screening-pipeline/matlab/data/train_data

echo "$(date): waiting for download to complete..."
while [ ! -f download_stdout.log ] || ! grep -q "DOWNLOAD_COMPLETE" download_stdout.log; do
  sleep 10
done
echo "$(date): download complete. Image count: $(find images -name '*.png' | wc -l)"

echo "$(date): launching pilot training (efficientnetb0)..."
/Applications/MATLAB_R2026a.app/bin/matlab -batch "run('/Users/aryanarora/Desktop/dr-screening-pipeline/matlab/scripts/train_module3_pilot.m')" \
  > /Users/aryanarora/Desktop/dr-screening-pipeline/matlab/data/train_data/pilot_training.log 2>&1

echo "$(date): PILOT TRAINING PIPELINE COMPLETE"
