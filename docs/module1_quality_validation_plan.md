# Module 1 Quality Gate: Second Real-World Validation — Plan (DRAFT, pending approval)

**Status: nothing in this plan has been run.** No downloads, no training
(this task doesn't train anything new — it validates existing code).

## 1. What this is

DDR's label files mark images as class 0-4 (gradable, real DR severity)
or **class 5 ("ungradable")** — a real quality judgment made by DDR's
original human graders. Module 3's `ddr_selection.txt` deliberately
excluded all 1,151 class-5 images (they were never downloaded), since
Module 3 only needed gradable images to train severity grading.

Those excluded images are real, labeled ground truth for exactly what
Module 1's `qualityGate.m` is supposed to catch, and a **second,
independent, larger check** than the existing DRIMDB calibration
(README documents 45 total images: 15 APTOS + 15 DRIMDB-good +
15 DRIMDB-bad). This adds up to 1,151 more real ungradable images plus a
matched gradable sample, from a completely different dataset/camera
population than DRIMDB.

**This is a validation task, not a training task.** `qualityGate.m`'s
classical heuristic (focus/illumination/FOV scoring) runs exactly as-is
against real labels — no retraining, no new thresholds tuned on this
data (tuning against the same set you evaluate on would invalidate the
check). If it performs poorly here, that's a real finding to act on
separately, not something to fix by curve-fitting to this specific set.

## 2. Proposed approach

```
matlab/data/train_data/
  download_ddr_ungradable.sh       pulls the 1,151 class-5 images (same
                                    per-file Kaggle pattern, same disk
                                    safety floor as download_ddr_subset.sh)
matlab/scripts/
  validate_module1_against_ddr.m   runs qualityGate.m on all 1,151 real
                                    ungradable images + an equal-sized
                                    random sample of known-gradable DDR
                                    images, reports sensitivity/specificity
```

Binary framing: `qualityGate.m`'s `accepted`/`enhanced` outputs both
count as "passed the gate" (gradable call); `rejected` counts as
"ungradable call" — matching how `run_pipeline.m` actually uses the
status (only `rejected` short-circuits the rest of the pipeline).

## 3. What's NOT done yet

1. Run `download_ddr_ungradable.sh` (1,151 images, similar-sized download
   to the original DDR pull — same disk-space consideration, should run
   after Module 3 finishes to avoid competing for the same headroom).
2. Run `validate_module1_against_ddr.m` and report real numbers.
3. **Decide in advance what result would actually change something**:
   if sensitivity/specificity here look similar to the DRIMDB numbers,
   that's reassuring confirmation, not new information requiring action.
   If they look meaningfully worse, the honest next step is investigating
   *why* (different camera/population than DRIMDB, same kind of gap
   Module 3 found with EyePACS) — not silently retuning thresholds
   against this exact test set.

## 4. Honest scope note

This does not add a new detectable condition or a new learned model —
it's due-diligence on an existing, shipped component, using data that
happened to be sitting unused after Module 3's selection process. Lowest
priority of the three plans if time is limited, since Module 1 is
already working and calibrated; this only checks whether that holds up
on a second, larger, independent sample.
