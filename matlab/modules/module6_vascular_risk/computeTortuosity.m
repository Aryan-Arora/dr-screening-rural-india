function result = computeTortuosity(segments)
%COMPUTETORTUOSITY Arc-chord tortuosity index, aggregated per vessel type.
%   result = COMPUTETORTUOSITY(segments) takes the same labeled segment
%   struct array classifyVesselSegments.m produces and returns:
%       arteryTortuosity, veinTortuosity - median (arcLength/chordLength - 1)
%                                           over that type's segments (0 =
%                                           perfectly straight; unitless)
%       overallTortuosity               - same, over all labeled segments
%                                           regardless of type
%       usable                          - false if too few labeled
%                                           segments exist to aggregate
%                                           meaningfully (values then [])
%
%   This is the standard arc-chord ratio (Grisan et al. and most of the
%   retinal-tortuosity literature use exactly this, sometimes with a
%   curvature-integral refinement this does NOT implement). No ground
%   truth available in this project to validate against, same status as
%   classifyVesselSegments.m and computeAVR.m -- treat as a rough,
%   directionally-meaningful signal, not a calibrated clinical score.
%
%   **Real bug found via end-to-end testing, fixed here**: classifying
%   segments after removing branch points (classifyVesselSegments.m) can
%   produce a handful of short fragments whose two endpoints happen to
%   land close together despite a longer skeleton path between them (a
%   small loop or near-doubling-back artifact from branch-point removal,
%   not a real long, gently-curving vessel). Those give a near-zero
%   chordLength with non-trivial arcLength, producing an enormous
%   arc/chord ratio (observed: single segments >6.0, versus a median
%   across the same image's segments of ~0.4) that swamps a plain mean.
%   Fixed two ways: (1) aggregate with the MEDIAN, not the mean, so a
%   handful of these outliers can't dominate; (2) drop segments with
%   chordLength below MIN_CHORD_LENGTH_PX entirely -- below that scale,
%   arc/chord ratio is measuring pixel-level path noise, not vessel
%   curvature, regardless of aggregation method.
%
%   Increased tortuosity (particularly arteriolar) is a reported retinal
%   correlate in the vascular-risk / stroke literature (e.g. tied to
%   hypertension and small-vessel disease), which is why this feeds
%   computeCerebrovascularRiskScore.m -- but that literature link is
%   population-level and correlational, not a per-patient diagnostic
%   threshold, and this implementation hasn't been checked against any of
%   it directly. **Also note**: these segments are short branch-to-branch
%   fragments (classifyVesselSegments.m's MIN_SEGMENT_LENGTH = 10px), not
%   the full disc-to-periphery vessel paths most published tortuosity-
%   index studies measure -- so absolute magnitudes here should NOT be
%   compared directly to published tortuosity-index values; only relative
%   comparisons across images computed the same way are meaningful.

MIN_SEGMENTS_PER_TYPE = 2;
MIN_CHORD_LENGTH_PX = 5;

if isempty(segments)
    result = unusableResult();
    return;
end

hasLabel = ~cellfun(@isempty, {segments.label});
labeled = segments(hasLabel & [segments.chordLength] >= MIN_CHORD_LENGTH_PX);

if isempty(labeled)
    result = unusableResult();
    return;
end

tortuosityOf = @(s) (s.arcLength / max(s.chordLength, eps)) - 1;
allTort = arrayfun(tortuosityOf, labeled);

arteries = labeled(strcmp({labeled.label}, 'artery'));
veins = labeled(strcmp({labeled.label}, 'vein'));

result.overallTortuosity = median(allTort);
result.usable = true;

if numel(arteries) >= MIN_SEGMENTS_PER_TYPE
    result.arteryTortuosity = median(arrayfun(tortuosityOf, arteries));
else
    result.arteryTortuosity = [];
end

if numel(veins) >= MIN_SEGMENTS_PER_TYPE
    result.veinTortuosity = median(arrayfun(tortuosityOf, veins));
else
    result.veinTortuosity = [];
end

end

function result = unusableResult()
result.arteryTortuosity = [];
result.veinTortuosity = [];
result.overallTortuosity = [];
result.usable = false;
end
