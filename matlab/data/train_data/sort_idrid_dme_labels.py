#!/usr/bin/env python3
"""Re-downloads IDRiD's label CSV (images are already on disk from the DR
run) and sorts images_idrid/ into a SEPARATE class-labeled tree by DME
risk grade instead of DR grade, for module8_macular_edema training.

NOT YET RUN -- part of the module8 draft pending review, see
docs/module8_macular_edema_plan.md. The original idrid_labels.csv was
deleted after Module 3's IDRiD images were sorted by DR grade only (a
real oversight -- flagged in the plan doc); this script re-fetches just
the small label CSV (not the 174MB of images, which are already here)
via the Kaggle API's single-file download, matching this project's
established -f-flag pattern (download_eyepacs.sh, download_ddr_subset.sh).
"""
import csv
import os
import shutil
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
IDRID_IMAGES = os.path.join(HERE, "images_idrid")  # already sorted by DR grade, class/idrid_<id>.jpg
OUT = os.path.join(HERE, "images_idrid_dme")

def fetch_label_csv():
    label_dir = os.path.join(HERE, "idrid_dme_labels")
    os.makedirs(label_dir, exist_ok=True)
    subprocess.run([
        "kaggle", "datasets", "download",
        "-d", "mariaherrerot/idrid-dataset",
        "-f", "idrid_labels.csv",
        "-p", label_dir, "--force",
    ], check=True)
    # kaggle CLI may save it zipped; handle both cases
    for f in os.listdir(label_dir):
        if f.endswith(".zip"):
            subprocess.run(["unzip", "-o", "-q", os.path.join(label_dir, f), "-d", label_dir], check=True)
    return os.path.join(label_dir, "idrid_labels.csv")

def main():
    csv_path = fetch_label_csv()
    os.makedirs(OUT, exist_ok=True)
    for c in ["0", "1", "2"]:
        os.makedirs(os.path.join(OUT, c), exist_ok=True)

    # Build id_code -> filename map from the already-sorted DR-grade tree
    # (filenames are "idrid_<id_code>.jpg" regardless of which DR-grade
    # folder they ended up in).
    id_to_path = {}
    for dr_class in os.listdir(IDRID_IMAGES):
        class_dir = os.path.join(IDRID_IMAGES, dr_class)
        if not os.path.isdir(class_dir):
            continue
        for fname in os.listdir(class_dir):
            if fname.startswith("idrid_"):
                id_code = fname[len("idrid_"):-len(".jpg")]
                id_to_path[id_code] = os.path.join(class_dir, fname)

    n, missing = 0, 0
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            id_code = row["id_code"].strip()
            dme = row.get("Risk of macular edema", "").strip()
            if not id_code or dme not in ("0", "1", "2"):
                continue
            src = id_to_path.get(id_code)
            if src is None:
                missing += 1
                continue
            dst = os.path.join(OUT, dme, f"idrid_{id_code}.jpg")
            shutil.copy(src, dst)
            n += 1

    print(f"sorted {n} images by DME risk grade, {missing} not found in images_idrid/")
    for c in ["0", "1", "2"]:
        count = len(os.listdir(os.path.join(OUT, c)))
        print(f"  class {c}: {count}")

if __name__ == "__main__":
    main()
