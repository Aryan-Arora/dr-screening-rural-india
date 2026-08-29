#!/bin/bash
# Fully unattended driver: waits for the DDR background download to
# finish, waits for both new MATLAB Add-Ons to be installed, combines
# the 3 datasets, then launches the 5-backbone training run. Designed to
# need no further human input once started.
set -u
cd "$(dirname "$0")"
LOG=run_full_training.log
exec >> "$LOG" 2>&1

echo "=== $(date) : run_full_training.sh started ==="

# ---- 1. Wait for DDR download to finish ----
EXPECTED_DDR=2049
while true; do
    n=$(find images_ddr -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$n" -ge "$EXPECTED_DDR" ] || grep -q "download complete" download_ddr.log 2>/dev/null; then
        echo "$(date) : DDR download done ($n/$EXPECTED_DDR files)"
        break
    fi
    if grep -q "^ABORT" download_ddr.log 2>/dev/null; then
        echo "$(date) : DDR download ABORTED (disk safety floor hit), proceeding with $n files anyway"
        break
    fi
    sleep 60
done

# ---- 2. Wait for both Add-Ons to be installed ----
MATLAB_BIN=$(ls -d /Applications/MATLAB_R*.app/bin/matlab 2>/dev/null | tail -1)
if [ -z "$MATLAB_BIN" ]; then
    MATLAB_BIN=matlab
fi
check_addons() {
    "$MATLAB_BIN" -batch "run('$(pwd)/check_addons.m')" 2>/dev/null | grep -q "^ *1$"
}

WAITED=0
MAX_WAIT=$((3 * 3600)) # give up waiting after 3 hours, proceed with whatever's available
while ! check_addons; do
    echo "$(date) : waiting for both Add-Ons to finish installing (waited ${WAITED}s)..."
    sleep 120
    WAITED=$((WAITED + 120))
    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
        echo "$(date) : gave up waiting for Add-Ons after 3h, proceeding anyway (train_module3_multi_dataset.m skips any backbone whose Add-On is missing)"
        break
    fi
done
echo "$(date) : Add-On check done, proceeding"

# ---- 3. Combine datasets ----
echo "$(date) : combining datasets"
./combine_datasets.sh

# ---- 4. Launch training ----
echo "$(date) : starting training"
cd ../../scripts
"$MATLAB_BIN" -batch "run('train_module3_multi_dataset.m')"
echo "$(date) : training script exited with code $?"
