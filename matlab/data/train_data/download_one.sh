#!/bin/bash
export PATH="$HOME/Library/Python/3.13/bin:$PATH"
cd "$(dirname "$0")"

id_code="$1"
diagnosis="$2"
dest="images/${diagnosis}/${id_code}.png"

if [ -f "$dest" ]; then
  exit 0
fi

kaggle datasets download -d mariaherrerot/aptos2019 \
  -f "train_images/train_images/${id_code}.png" \
  -p "images/${diagnosis}" --force -q 2>>download.log

if [ -f "images/${diagnosis}/${id_code}.png.zip" ]; then
  unzip -o -q "images/${diagnosis}/${id_code}.png.zip" -d "images/${diagnosis}/"
  rm -f "images/${diagnosis}/${id_code}.png.zip"
fi
