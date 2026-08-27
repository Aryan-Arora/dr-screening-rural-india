#!/bin/bash
export PATH="$HOME/Library/Python/3.13/bin:$PATH"
cd "$(dirname "$0")"

mkdir -p images/0 images/1 images/2 images/3 images/4

download_one() {
  local image_id="${1//$'\r'/}"
  local diagnosis="${2//$'\r'/}"
  local dest="images/${diagnosis}/eyepacs_${image_id}.jpeg"
  if [ -f "$dest" ]; then
    return 0
  fi
  local attempt=0
  until kaggle datasets download -d rohitmbansode/eyepacs-diabetic-retinopathy-detection \
      -f "EyePACS_DR_Detection/Train/${image_id}.jpeg" \
      -p "images/${diagnosis}" --force -q >>download_eyepacs.log 2>&1; do
    attempt=$((attempt+1))
    if [ $attempt -ge 3 ]; then
      echo "FAILED: $image_id" >> failed_eyepacs.log
      return 1
    fi
    sleep $((attempt * 3))
  done
  local downloaded="images/${diagnosis}/${image_id}.jpeg"
  if [ -f "${downloaded}.zip" ]; then
    unzip -o -q "${downloaded}.zip" -d "images/${diagnosis}/"
    rm -f "${downloaded}.zip"
  fi
  if [ -f "$downloaded" ] && [ "$downloaded" != "$dest" ]; then
    mv "$downloaded" "$dest"
  fi
  echo "$image_id" >> downloaded_eyepacs.log
  sleep 0.3
}
export -f download_one

tail -n +2 eyepacs_selection.csv | awk -F',' '{print $1" "$2}' | \
  xargs -P 3 -L 1 bash -c 'download_one "$0" "$1"'

echo "EYEPACS_DOWNLOAD_COMPLETE"
