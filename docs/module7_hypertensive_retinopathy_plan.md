# Module 7: Learned Hypertensive-Retinopathy Classifier — Plan (DRAFT, pending approval)

**Status: nothing in this plan has been run.** Code is scaffolded (see
"Files written" below), datasets are surveyed but not downloaded, no
training has happened. This is written for review before any of it
executes.

## 1. What this actually is (scope, stated plainly)

Following up on Module 6 (`module6_vascular_risk/`, already shipped): that
module estimates stroke/vascular-dementia risk from AVR, vessel
tortuosity, and fractal dimension — all classical computer vision, no
learned model, and `classifyHypertensiveRetinopathy.m`'s hypertensive-
narrowing grade is currently a simple AVR-threshold heuristic.

The ask was to train a **learned model**, like Module 3's CNN ensemble,
for "the brain disease problem." Before building anything, I checked what
that can honestly mean given what data actually exists publicly:

- **Searched for a dataset linking retinal images to real stroke or
  dementia outcomes**: nothing found. Zero results for "AVR ratio
  retinal" or "stroke retinal fundus" on Kaggle. That data exists in
  restricted longitudinal cohorts (UK Biobank, ARIC, Rotterdam Study) that
  require formal, multi-week data-access applications — not obtainable
  the way APTOS/IDRiD/DDR were for Module 3.
- **What IS real and trainable**: hypertensive retinopathy — the direct,
  clinically visible retinal finding that is itself an established risk
  marker for stroke/cerebrovascular disease. A real, well-used, labeled
  dataset exists for this specific task (see below).

**So this plan trains a hypertensive-retinopathy image classifier, not a
stroke/dementia/Alzheimer's predictor.** Its output replaces or
supplements the current AVR-threshold heuristic in
`classifyHypertensiveRetinopathy.m`, which continues to feed the same
composite `computeCerebrovascularRiskScore.m` as before. This is a real
upgrade (learned model vs. hand-picked threshold), not a claim to detect
a new condition.

## 2. Dataset survey

| Dataset | Size | Kaggle usage signal | Verdict |
|---|---|---|---|
| `harshwardhanfartale/hypertension-and-hypertensive-retinopathy-dataset` | ~1.0 GB | 1,011 downloads, 11 votes | **Recommended primary source.** Structure confirmed: `1-Hypertensive Classification/.../1-Images/1-Training Set/*.png` — appears to be a mirror of the real HRDC (Hypertensive Retinopathy Diagnosis Challenge, MICCAI 2024) dataset. Binary label (hypertensive / non-hypertensive) is the real, established task. |
| `andrewmvd/ocular-disease-recognition-odir5k` (ODIR-5K) | ~1.7 GB | 65,017 downloads, 566 votes — by far the most-used dataset checked | **Strong candidate, worth using alongside or instead of HRDC.** Multi-label (8 categories including native "hypertension" label, plus diabetes/glaucoma/AMD/cataract/myopia/other/normal) from a well-known, heavily-vetted ophthalmology dataset. Left/right eye images confirmed present; label CSV not yet inspected in this draft. |
| `shashwatwork/identification-of-pseudopapilledema` | ~23 MB | 748 downloads, 18 votes | Interesting but out of scope for now — distinguishes real papilledema (raised intracranial pressure, a genuine brain-disease sign) from pseudopapilledema (benign look-alike). Small, binary, class-named folders (`Normal/`, likely one more). **Flagged as a good follow-up module, not part of this plan** — different clinical finding from hypertensive retinopathy, would need its own module. |
| Glaucoma datasets (SMDG, EyePACS-AIROGS) | 3.1 GB / 550 MB | 6,536 / 4,933 downloads | **Rejected for the "brain disease" framing.** Glaucoma is real, well-supported, and technically involves the optic nerve (CNS), but it's a distinct degenerative eye disease with no established stroke/dementia link — including it here would repeat exactly the scope-overreach mistake already caught and avoided with Alzheimer's in Module 6. Worth its own module someday under its own honest label ("glaucoma detection"), not this one. |
| AMD datasets (Macular Degeneration, ARMD) | 600 MB / 45 MB | 678 / 1,100 downloads | **Rejected, same reasoning as glaucoma** — retinal degenerative disease, not a brain-disease correlate. |

**Recommendation**: start with the dedicated hypertensive-retinopathy
dataset (clean, single-purpose, real HRDC-style task). If results look
promising, ODIR-5K's "hypertension" label subset is a plausible way to
add volume/diversity later — same domain-gap check discipline as
Module 3 (train on one, evaluate per-source) would apply before blending.

## 3. Proposed pipeline architecture

Mirrors Module 3's structure exactly, in a new `module7_hypertensive_grading/`
folder rather than modifying Module 3's shared files while its training
run is active:

```
matlab/modules/module7_hypertensive_grading/
  buildHypertensiveBackbone.m    same 5 backbones as Module 3, 2-class head
  prepareHRDCDatastore.m         70/15/15 stratified split, same fixed seed (42)
  trainHypertensiveClassifier.m  fine-tune + evaluate one backbone, binary sens/spec
matlab/scripts/
  train_module7_hypertensive.m   orchestrates all 5 backbones + summary
matlab/data/train_data/
  download_hrdc_dataset.sh       Kaggle CLI download (not yet run)
```

**Deliberate near-duplication of `buildBackbone.m`**, not a shared
`numClasses` parameter: this was written while Module 3's multi-dataset
run was actively using `buildBackbone.m`. Editing a shared function
mid-run risked destabilizing hours of in-progress training for an
unapproved feature. **Once this plan is approved and Module 3's run is
done, the natural cleanup is merging these into one parameterized
function** — flagged here so it isn't forgotten as permanent debt.

## 4. What's NOT done yet (needs your approval + these next steps)

1. **Run `download_hrdc_dataset.sh`** and inspect the actual label
   format — the real HRDC download's structure (label CSV vs.
   class-named folders) wasn't confirmed in this draft, to avoid using
   disk space while Module 3's run needs its own headroom. It's likely
   the `1-Hypertensive Classification` folder structure implies a
   train/test split with a separate labels file; `prepareHRDCDatastore.m`
   currently assumes simple class-named subfolders and may need a
   label-sorting step first (same pattern as `combine_datasets.sh` did
   for DDR's `train.txt`/`valid.txt`/`test.txt`).
2. **Wait for Module 3's current run to finish** — no GPU/Parallel
   Computing Toolbox on this machine, so running both training jobs at
   once would slow both down unpredictably and make timing estimates
   meaningless for both.
3. **Design the actual wiring** into `classifyHypertensiveRetinopathy.m`
   — proposed: try loading a trained model first, fall back to the
   current AVR-threshold heuristic if none exists (same
   graceful-degradation pattern `run_pipeline.m` already uses for Module
   3's models). Not implemented yet, pending approval of the overall
   direction.
4. **Decide**: HRDC alone, or HRDC + ODIR-5K's hypertension subset
   blended (with the same per-source domain-gap check Module 3 now has)?

## 5. Honest risk/limitations recap

- Sensitivity/specificity targets: no PRD-equivalent target exists for
  this task (the PRD only specifies DR success metrics) — worth deciding
  what threshold would make this worth shipping before training, not
  after.
- Even a well-trained hypertensive-retinopathy classifier only replaces
  the *narrowing-grade* input to the existing heuristic composite risk
  score — it does not, and cannot with data available today, become a
  validated stroke or dementia predictor.
- Same unvalidated-until-proven-otherwise posture as every other
  first-pass detector in this project: real training will be reported
  with real numbers, not assumed to work because the architecture is
  copied from Module 3.
