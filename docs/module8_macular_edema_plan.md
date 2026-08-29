# Module 8: Diabetic Macular Edema (DME) Risk Grading — Plan (DRAFT, pending approval)

**Status: nothing in this plan has been run.** Code scaffolded, no
downloads beyond what already exists, no training.

## 1. What this is

IDRiD's label CSV (downloaded for Module 3's IDRiD data, but only the
`diagnosis` column was used) has a second real label column: **"Risk of
macular edema"** (grades 0/1/2). This is a genuine, separate clinical
finding from DR severity — a diabetic patient can have edema risk without
severe retinopathy or vice versa — and IDRiD's own paper treats it as an
independent grading task.

**Honest correction, stated plainly**: `idrid_labels.csv` was deleted
after Module 3's IDRiD images were sorted by DR grade, discarding this
column without noticing it at the time. It's cheaply recoverable — the
label CSV is a tiny download (part of the same 174MB dataset already
pulled once) and all 455 images are still on disk in `images_idrid/`.
`sort_idrid_dme_labels.py` re-fetches just the CSV and re-sorts the
already-downloaded images by DME grade instead.

## 2. Data reality check (important, unlike Module 3/7)

**Only 455 images total** — the entire IDRiD set, no DDR/APTOS equivalent
exists for DME (neither dataset provides this label). A 70/15/15 split
leaves roughly a 68-image test set. This will produce meaningfully
noisier numbers than Module 3's 813-image or Module 7's larger test sets
— a few images flipping prediction moves accuracy by 1-2 percentage
points. Worth deciding now whether that's still useful (a real, if noisy,
first-pass signal) or not worth training at all versus just reporting
"not attempted, insufficient data" like Module 4 did for venous
beading/IRMA.

**My recommendation**: still worth training — even a noisy real
classifier beats the current `null` value in the pipeline's output, and
the honesty precedent throughout this project is to ship real numbers
with stated caveats, not withhold something workable. But report the
small-n caveat prominently in any output, exactly like `trainDMEClassifier.m`
already does in its console output.

## 3. Proposed pipeline architecture

Mirrors Module 3/7's structure:

```
matlab/modules/module8_macular_edema/
  buildDMEBackbone.m       same 5 backbones, 3-class head
  prepareDMEDatastore.m    70/15/15 stratified split, seed 42
  trainDMEClassifier.m     fine-tune + evaluate, "referable" (grade>=1) framing
matlab/scripts/
  train_module8_dme.m      orchestrates all 5 backbones + summary
matlab/data/train_data/
  sort_idrid_dme_labels.py re-fetches label CSV, re-sorts existing images
```

Same deliberate near-duplication of `buildBackbone.m` as Module 7, same
reasoning (written without touching shared files mid-run), same flagged
cleanup once approved.

## 4. What's NOT done yet

1. Run `sort_idrid_dme_labels.py` to build `images_idrid_dme/`.
2. Wait for Module 3 (and Module 7, if approved first) to finish training.
3. Decide wiring: this would be a new `dme_risk` field in
   `run_pipeline.m`'s output JSON (not in the PRD's original fixed
   contract, same "extra field, doesn't break existing parsing" approach
   as Module 6's `vascular_risk`).
4. No PRD-equivalent target metric exists for DME — worth agreeing on a
   bar (e.g. matching DR's referable-sensitivity framing) before training,
   not after.

## 5. Honest risk/limitations recap

- Single-source (IDRiD only), 455 images — the smallest, least
  statistically solid training set in this project by a wide margin.
- No domain-gap check possible (nothing to compare against — DDR/APTOS
  don't have this label), unlike Module 3's per-source breakdown.
- Same unvalidated-until-real-numbers-exist posture as everything else
  here.
