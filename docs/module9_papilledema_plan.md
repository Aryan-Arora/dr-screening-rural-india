# Module 9: Papilledema Detection — Plan (DRAFT, pending approval)

**Status: nothing has been trained.** Dataset was downloaded once to
verify its real structure (23MB, deleted after inspection), code is
scaffolded, no training has run.

## 1. Why papilledema specifically

Across everything surveyed for "brain disease detection from fundus
images" (see the earlier tiered list), papilledema is the **only
candidate that is a direct visible manifestation of brain disease**,
not a population-level risk correlate. Module 6's stroke/dementia risk
score and Module 7's hypertensive retinopathy are both "this retinal
sign is statistically associated with elevated risk of X" — real, but
one inferential step removed from the disease itself. Papilledema is
different: **the optic disc swelling IS the diagnostic sign**, seen
directly on fundus exam, and finding it is a real, standard part of how
raised intracranial pressure gets caught in clinical practice.

## 2. Clinical background (what's actually being detected)

**Papilledema** = optic disc swelling caused specifically by raised
intracranial pressure (ICP). Causes include:
- Brain tumor (mass effect / obstructing CSF flow)
- Idiopathic intracranial hypertension (IIH / pseudotumor cerebri)
- Hydrocephalus
- Cerebral venous sinus thrombosis
- Severe hypertension (malignant hypertension can also cause disc
  swelling — a real overlap point with Module 6's territory, worth
  keeping in mind, not a separate mechanism to worry about here)

Visible signs on a fundus photo: blurred/elevated disc margins,
hyperemia (redness) of the disc, vessels partially obscured where they
cross the swollen margin, and in more severe cases hemorrhages or
cotton-wool spots right at the disc.

**Pseudopapilledema** = a disc that LOOKS swollen but isn't, from a
completely different, usually benign mechanism (most commonly optic disc
drusen — calcified deposits within the disc, or a congenitally
crowded/anomalous disc shape). Critically, **this looks similar enough
to real papilledema that misdiagnosis is a well-documented real clinical
problem** — this is exactly why the dataset below treats it as its own
third class rather than lumping it with "normal": distinguishing true
papilledema from pseudopapilledema is itself the hard, valuable part of
this task, not an afterthought.

**What a positive result would actually mean**: "refer for urgent
neuroimaging / neurology workup," not a diagnosis of any specific
underlying cause. A detected papilledema case still needs an MRI/CT and
clinical correlation to find out *why* — same category of caveat as
everything else in this project: this flags a finding, it doesn't
diagnose the disease behind it.

## 3. Dataset (verified by direct download + inspection, not just the listing)

`shashwatwork/identification-of-pseudopapilledema` on Kaggle (748
downloads, 18 votes, 0.875 usability rating — the most credible option
found among several similarly-named smaller mirrors, which is why this
one and not the others):

| Class | Count |
|---|---|
| Papilledema | 295 |
| Pseudopapilledema | 295 |
| Normal | 779 |
| **Total** | **1,369** |

Real, balanced enough to train on directly (Normal is ~2.6x either
disease class — handled with the same inverse-frequency weighted
cross-entropy every other module here uses, not a new technique).

## 4. Proposed pipeline architecture

Same 5-backbone pattern as every other module:

```
matlab/modules/module9_papilledema/
  buildPapilledemaBackbone.m       same 5 backbones, 3-class head
  preparePapilledemaDatastore.m    70/15/15 stratified split, seed 42
  trainPapilledemaClassifier.m     fine-tune + evaluate, papilledema-vs-rest framing
matlab/scripts/
  train_module9_papilledema.m      orchestrates all 5 backbones + summary
matlab/data/train_data/
  download_papilledema_dataset.sh  Kaggle CLI download
```

**Evaluation framing, different from other modules**: reports
sensitivity/specificity for **papilledema vs. everything else**
(pseudopapilledema + normal combined), not raw 3-class accuracy. A
missed true papilledema is a missed brain-disease referral — the
clinically expensive error; mistaking pseudopapilledema for papilledema
is a false alarm that gets sorted out by the neuroimaging referral, not
a missed diagnosis. This mirrors Module 3's "referable vs. non-referable"
reframing of raw ICDR accuracy.

**Considered but not built yet**: cropping to the optic disc region
first, reusing Module 2's `localizeOpticDisc.m`, since papilledema signs
are localized to the disc rather than distributed across the whole
retina (unlike DR, where lesions can be anywhere). This is a genuinely
promising preprocessing idea — worth trying if the whole-image baseline
underperforms — but adds real complexity (needs disc localization to
succeed on every training image, and Module 2's own README numbers show
disc localization confidence isn't perfect on 100% of images). Flagged
as a documented next step, not built into this first draft, to keep the
initial version simple and comparable to how every other module started.

## 5. What's NOT done yet

1. Run `download_papilledema_dataset.sh` for real (only did a
   verify-then-delete pass during planning).
2. Wait for Module 3's training to finish (and Module 7/8, if approved
   first) — CPU contention.
3. Decide wiring: proposed as a new `papilledema` field in
   `run_pipeline.m`'s output, same "extra field, doesn't break existing
   contract" approach as Module 6.
4. No PRD-equivalent target exists for this — worth agreeing what
   sensitivity bar would make this trustworthy enough to surface as an
   urgent-referral flag before training, given a false negative here is
   the most clinically serious miss of any module in this project.

## 6. Honest risk/limitations recap

- 1,369 images is a real, moderate-size dataset — bigger than Module 8's
  455, smaller than Module 3's combined 5,434. Expect results between
  those two in terms of statistical noise.
- Single dataset, single source — no second dataset exists to run the
  domain-gap check Module 3 got to do with APTOS/IDRiD/DDR.
- **This is the highest-stakes false-negative of any module built so
  far** — a missed papilledema case means a missed brain tumor/IIH/etc.
  referral. Whatever sensitivity number training produces needs to be
  reported with that stakes context front and center, not buried in a
  confusion matrix.
