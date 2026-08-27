function result = detectHemorrhages(img, vesselMask, fovMask, discCenter, discRadius, foveaCenter, exudateMask)
%DETECTHEMORRHAGES Classical-CV hemorrhage candidate detection.
%   result = DETECTHEMORRHAGES(img, vesselMask, fovMask, discCenter,
%   discRadius, foveaCenter, exudateMask) returns a struct:
%       count      - number of hemorrhage-like candidates found
%       centroids  - Nx2 [x y] candidate locations, REF_SIZE coordinates
%
%   Same validation caveat as the other Module 2 lesion detectors: NOT
%   checked against pixel-level ground truth.
%
%   Method: same dark-structure top-hat as detectMicroaneurysms, but with
%   a wider background-closing structuring element (disk 25 vs disk 9),
%   since hemorrhages are larger than microaneurysms. That size difference
%   matters mechanically, not just as a filter parameter: a morphological
%   top-hat can only respond to features SMALLER than its closing
%   structuring element, so reusing the MA-scale element here produced
%   exactly zero candidates above ~4px regardless of what was actually in
%   the image -- a scale-mismatch bug, not a "no hemorrhages" result.
%
%   Three false-positive sources found during development, on top of the
%   usual field-boundary/vessel exclusions:
%     1. The optic disc (excluded, 2.5x disc radius).
%     2. The fovea's own natural pit/shadow -- a smooth, large dark region
%        at exactly hemorrhage scale, easily mistaken for pathology
%        (excluded, 1.2x disc radius around the fovea center).
%     3. Exudates (bright lesions, detected separately) commonly have a
%        shadowed edge that a pure dark-structure detector misreads as a
%        distinct lesion. A per-centroid circular exclusion wasn't enough
%        for large/irregular exudate clusters -- needed the actual
%        exudate mask (dilated) to fully cover the irregular shape.

REF_SIZE = size(img, 1);
green = im2double(img(:, :, 2));

enhanced = adapthisteq(green, 'ClipLimit', 0.008, 'NumTiles', [8 8]);
bg = imclose(enhanced, strel('disk', 25));
darkResponse = imsubtract(bg, enhanced);

equivRadius = sqrt(sum(fovMask(:)) / pi);
interiorMask = imerode(fovMask, strel('disk', round(equivRadius * 0.08)));
darkResponse(~interiorMask) = 0;

dthresh = graythresh(darkResponse(interiorMask)) * 1.5;
darkMask = darkResponse > dthresh;

[X, Y] = meshgrid(1:REF_SIZE, 1:REF_SIZE);
discExclude = (X - discCenter(1)).^2 + (Y - discCenter(2)).^2 <= (discRadius * 2.5)^2;
foveaExclude = (X - foveaCenter(1)).^2 + (Y - foveaCenter(2)).^2 <= (discRadius * 1.2)^2;
exudateExclude = imdilate(exudateMask, strel('disk', 10));
vesselExclude = imdilate(vesselMask, strel('disk', 4));

candidateMask = darkMask & ~vesselExclude & interiorMask & ~discExclude & ~foveaExclude & ~exudateExclude;
candidateMask = bwareaopen(candidateMask, 10);

cc = bwconncomp(candidateMask);
stats = regionprops(cc, 'EquivDiameter', 'Centroid');

% Dot/blot hemorrhages are round-ish like oversized MAs; flame
% hemorrhages streak along the nerve fiber layer and are more elongated,
% so unlike MA detection this doesn't filter on roundness -- just size.
isHem = arrayfun(@(s) s.EquivDiameter > 8 && s.EquivDiameter <= 40, stats);
hemStats = stats(isHem);

result.count = numel(hemStats);
if isempty(hemStats)
    result.centroids = zeros(0, 2);
else
    result.centroids = reshape([hemStats.Centroid], 2, [])';
end

end
