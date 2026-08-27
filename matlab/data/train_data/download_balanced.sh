#!/bin/bash
export PATH="$HOME/Library/Python/3.13/bin:$PATH"
cd "$(dirname "$0")"

mkdir -p images/0 images/1 images/2 images/3 images/4

download_one() {
  local id_code="${1//$'\r'/}"
  local diagnosis="${2//$'\r'/}"
  local dest="images/${diagnosis}/${id_code}.png"
  if [ -f "$dest" ]; then
    return 0
  fi
  local attempt=0
  until kaggle datasets download -d mariaherrerot/aptos2019 \
      -f "train_images/train_images/${id_code}.png" \
      -p "images/${diagnosis}" --force -q >>download.log 2>&1; do
    attempt=$((attempt+1))
    if [ $attempt -ge 3 ]; then
      echo "FAILED: $id_code" >> failed.log
      return 1
    fi
    sleep $((attempt * 3))
  done
  if [ -f "images/${diagnosis}/${id_code}.png.zip" ]; then
    unzip -o -q "images/${diagnosis}/${id_code}.png.zip" -d "images/${diagnosis}/"
    rm -f "images/${diagnosis}/${id_code}.png.zip"
  fi
  echo "$id_code" >> downloaded.log
  sleep 0.3
}
export -f download_one

tail -n +2 balanced_selection.csv | awk -F',' '{print $1" "$2}' | \
  xargs -P 3 -L 1 bash -c 'download_one "$0" "$1"'

echo "DOWNLOAD_COMPLETE"
