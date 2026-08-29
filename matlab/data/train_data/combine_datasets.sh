#!/bin/bash
# Builds images_combined/<class>/ as SYMLINKS (not copies -- same
# disk-space-saving pattern as the old images_aptos_only/ view) merging:
#   - images/            APTOS-only files (real dataset, NOT the stray
#                        leftover eyepacs_-prefixed files also sitting in
#                        that directory from the earlier, abandoned
#                        EyePACS blend -- see README's Module 3 section
#                        for why that blend was dropped; explicitly
#                        excluded here so this new run doesn't
#                        accidentally resurrect it)
#   - images_idrid/      IDRiD (Kaggle mirror mariaherrerot/idrid-dataset)
#   - images_ddr/        curated DDR subset (ddr_selection.txt)
# Every linked filename is prefixed with its source (aptos_/idrid_/ddr_)
# so ensembleGrade.m's per-source domain-gap check can recover the source
# from the test set's filenames after prepareDatastore.m's random split.
set -e
cd "$(dirname "$0")"

OUT=images_combined
rm -rf "$OUT"
mkdir -p "$OUT"/{0,1,2,3,4}

n_aptos=0
n_idrid=0
n_ddr=0

for c in 0 1 2 3 4; do
  for f in images/$c/*; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
      eyepacs_*) continue ;; # excluded, see header comment
    esac
    ln -s "$(pwd)/$f" "$OUT/$c/aptos_${base}"
    n_aptos=$((n_aptos+1))
  done
  for f in images_idrid/$c/*; do
    [ -e "$f" ] || continue
    base=$(basename "$f") # already idrid_-prefixed
    ln -s "$(pwd)/$f" "$OUT/$c/$base"
    n_idrid=$((n_idrid+1))
  done
  for f in images_ddr/$c/*; do
    [ -e "$f" ] || continue
    base=$(basename "$f") # already ddr_-prefixed
    ln -s "$(pwd)/$f" "$OUT/$c/$base"
    n_ddr=$((n_ddr+1))
  done
done

echo "combined: aptos=$n_aptos idrid=$n_idrid ddr=$n_ddr total=$((n_aptos+n_idrid+n_ddr))"
for c in 0 1 2 3 4; do
  echo "  class $c: $(ls "$OUT/$c" | wc -l)"
done
