function result = computeAVR(segments, discRadius)
%COMPUTEAVR Central retinal arteriole/venule equivalents (CRAE/CRVE) and
%   their ratio (AVR), using segments already labeled by
%   classifyVesselSegments.m.
%   result = COMPUTEAVR(segments, discRadius) returns a struct:
%       CRAE, CRVE   - central retinal artery/vein equivalent widths (px)
%       AVR          - CRAE / CRVE
%       numArteries, numVeins - how many zone-B segments contributed
%       usable       - false if too few vessels were found in zone B to
%                      compute a meaningful equivalent (in which case
%                      CRAE/CRVE/AVR are all [])
%
%   Measurement zone: the standard "zone B" annulus from retinal vascular
%   epidemiology protocols (Hubbard et al. 1999, used by ARIC/Rotterdam/
%   Beaver Dam) -- 0.5 to 1.0 disc diameters out from the disc MARGIN.
%   In distance-from-disc-CENTER terms with disc radius R: that's the
%   annulus from 2R to 3R (margin is at 1R; +0.5*2R=+1R gives 2R; +1.0*2R
%   gives 4R... actually: 0.5 diameters = 1R, 1.0 diameters = 2R, so the
%   annulus is [R + 1R, R + 2R] = [2R, 3R] from center).
%
%   Combining formula: Knudtson et al.'s 2003 revised formula (the
%   standard used in preference to the older Parr-Hubbard formula in
%   modern literature), applied iteratively pairing the two most similar
%   remaining widths at each step until one value per vessel type remains:
%       artery pair:  w_combined = 0.88 * sqrt(w1^2 + w2^2)
%       vein pair:    w_combined = 0.95 * sqrt(w1^2 + w2^2)
%   Standard protocol uses the 6 largest vessels of each type; this
%   implementation uses however many are found in zone B, capped at 6,
%   with a minimum of 2 per type to compute anything at all.

MIN_VESSELS_PER_TYPE = 2;
MAX_VESSELS_PER_TYPE = 6;

if isempty(segments)
    result = unusableResult();
    return;
end

inZone = [segments.distFromDisc] >= 2 * discRadius & [segments.distFromDisc] <= 3 * discRadius;
labeled = segments(inZone & ~cellfun(@isempty, {segments.label}));

arteries = labeled(strcmp({labeled.label}, 'artery'));
veins = labeled(strcmp({labeled.label}, 'vein'));

if numel(arteries) < MIN_VESSELS_PER_TYPE || numel(veins) < MIN_VESSELS_PER_TYPE
    result = unusableResult();
    result.numArteries = numel(arteries);
    result.numVeins = numel(veins);
    return;
end

arteryWidths = sort([arteries.meanWidth], 'descend');
arteryWidths = arteryWidths(1:min(MAX_VESSELS_PER_TYPE, numel(arteryWidths)));
veinWidths = sort([veins.meanWidth], 'descend');
veinWidths = veinWidths(1:min(MAX_VESSELS_PER_TYPE, numel(veinWidths)));

CRAE = knudtsonCombine(arteryWidths, 0.88);
CRVE = knudtsonCombine(veinWidths, 0.95);

result.CRAE = CRAE;
result.CRVE = CRVE;
result.AVR = CRAE / CRVE;
result.numArteries = numel(arteries);
result.numVeins = numel(veins);
result.usable = true;

end

% ---- helpers ----------------------------------------------------------

function combined = knudtsonCombine(widths, coefficient)
%KNUDTSONCOMBINE Iteratively pair-combine vessel widths per Knudtson's
%   revised formula until one equivalent value remains. Standard protocol
%   pairs the largest with the smallest at each round (not arbitrary
%   adjacent pairing) to avoid one large outlier dominating the result.
while numel(widths) > 1
    widths = sort(widths, 'descend');
    n = numel(widths);
    newWidths = zeros(1, ceil(n / 2));
    for i = 1:floor(n / 2)
        w1 = widths(i);
        w2 = widths(n - i + 1);
        newWidths(i) = coefficient * sqrt(w1^2 + w2^2);
    end
    if mod(n, 2) == 1
        newWidths(end) = widths(ceil(n / 2));
    end
    widths = newWidths;
end
combined = widths(1);
end

function result = unusableResult()
result.CRAE = [];
result.CRVE = [];
result.AVR = [];
result.numArteries = 0;
result.numVeins = 0;
result.usable = false;
end
