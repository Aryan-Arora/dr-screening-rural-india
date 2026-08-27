function result = computeCerebrovascularRiskScore(avrResult, tortuosityResult, fractalResult)
%COMPUTECEREBROVASCULARRISKSCORE Heuristic composite stroke/vascular-
%   dementia risk flag from three retinal vascular biomarkers.
%   result = COMPUTECEREBROVASCULARRISKSCORE(avrResult, tortuosityResult, fractalResult)
%   combines computeAVR.m, computeTortuosity.m, and computeFractalDimension.m
%   output into:
%       score       - [0, 1] composite, higher = more retinal signal
%                     consistent with elevated cerebrovascular risk
%       category    - 'low' | 'moderate' | 'high'
%       components  - struct listing each sub-score actually used and
%                     which ones were skipped (and why)
%       usable      - false if NONE of the three inputs were usable
%
%   **Scope, stated plainly, because it matters for how this gets used:**
%   this flags shared-mechanism SMALL-VESSEL cerebrovascular risk --
%   stroke and vascular dementia/cognitive decline both arise from the
%   same underlying small-vessel disease process, and reduced AVR,
%   increased arteriolar tortuosity, and reduced retinal vascular fractal
%   dimension are each independently associated with BOTH outcomes in
%   large population cohorts (stroke: ARIC, Rotterdam, Cheung et al.'s
%   fractal-dimension work; cognitive decline/vascular dementia:
%   Cardiovascular Health Study, Rotterdam again -- same small-vessel
%   mechanism, which is why the same three biomarkers show up in both
%   literatures). Those are population-level, risk-factor-adjusted
%   epidemiological associations, NOT a per-patient predictive model with
%   a validated decision threshold, and every upstream component here is
%   itself unvalidated (see each one's own header comment) -- treat
%   `category` as "retinal small-vessel signal worth a specialist's
%   attention", never as a stroke or dementia diagnosis.
%
%   **This does NOT detect Alzheimer's disease, early-onset or otherwise,
%   and should never be presented as if it does.** Alzheimer's pathology
%   is primarily amyloid/tau-driven, a different mechanism from the
%   vascular one these three biomarkers measure. The actual retinal
%   research for Alzheimer's uses OCT-based retinal nerve fiber
%   layer/ganglion cell thinning or retinal amyloid fluorescence imaging
%   -- neither is obtainable from a color fundus photo with classical
%   vessel-morphology CV, which is all this module has. Deliberately not
%   attempted, same reasoning this project has applied everywhere else:
%   don't ship a number the evidence and the input data can't support.
%
%   Combining the three sub-scores as an unweighted mean is a project-
%   specific simplification with no outcome data available to calibrate
%   weights against. Reference midpoints (AVR 0.66, tortuosity 0.05,
%   fractal dimension 1.7 -- each "healthy-typical" per general
%   literature) are approximate population medians, not patient-specific
%   norms.

components = struct('avr', [], 'tortuosity', [], 'fractal', []);
skipped = {};

subScores = [];

if avrResult.usable && ~isempty(avrResult.AVR)
    % Lower AVR = more narrowing = higher risk. 0.66 = healthy-typical
    % reference; clamp to [0,1] over a 0.66-down-to-0.30 span (0.30 taken
    % as a severe-narrowing floor, below which the score saturates at 1).
    s = clamp((0.66 - avrResult.AVR) / (0.66 - 0.30), 0, 1);
    components.avr = s;
    subScores(end+1) = s;
else
    skipped{end+1} = 'AVR (insufficient artery/vein segments in zone B)';
end

if tortuosityResult.usable && ~isempty(tortuosityResult.overallTortuosity)
    % Higher tortuosity = higher risk. 0.05 = near-straight reference,
    % 0.30 = a pragmatic "clearly tortuous" ceiling for saturation.
    s = clamp((tortuosityResult.overallTortuosity - 0.05) / (0.30 - 0.05), 0, 1);
    components.tortuosity = s;
    subScores(end+1) = s;
else
    skipped{end+1} = 'tortuosity (no labeled segments to average)';
end

if fractalResult.usable && ~isempty(fractalResult.Dbox)
    % Lower fractal dimension = sparser tree = higher risk. 1.7 =
    % healthy-typical reference, 1.35 = a pragmatic "clearly reduced"
    % floor for saturation.
    s = clamp((1.7 - fractalResult.Dbox) / (1.7 - 1.35), 0, 1);
    components.fractal = s;
    subScores(end+1) = s;
else
    skipped{end+1} = 'fractal dimension (too few vessel pixels in ROI)';
end

if isempty(subScores)
    result.score = [];
    result.category = [];
    result.components = components;
    result.skipped = skipped;
    result.usable = false;
    return;
end

score = mean(subScores);
if score < 1/3
    category = 'low';
elseif score < 2/3
    category = 'moderate';
else
    category = 'high';
end

result.score = score;
result.category = category;
result.components = components;
result.skipped = skipped;
result.usable = true;

end

function y = clamp(x, lo, hi)
y = min(max(x, lo), hi);
end
