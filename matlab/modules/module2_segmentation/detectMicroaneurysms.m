function result = detectMicroaneurysms(img, vesselMask, fovMask)
%DETECTMICROANEURYSMS Classical-CV microaneurysm (MA) candidate detection.
%   result = DETECTMICROANEURYSMS(img, vesselMask, fovMask) returns a
%   struct:
%       count      - number of MA-like candidates found
%       centroids  - Nx2 [x y] candidate locations, REF_SIZE coordinates
%
%   img/vesselMask/fovMask must be in the same REF_SIZE x REF_SIZE space
%   as segmentVessels' output.
%
%   IMPORTANT LIMITATION: this has NOT been validated against pixel-level
%   ground truth (IDRiD has exactly this kind of annotation but requires
%   IEEE DataPort registration we don't have). Classical MA detection is a
%   genuinely hard, actively-researched problem even in published
%   literature with far more sophisticated multi-scale/wavelet methods --
%   treat this as a rough first-pass candidate detector, not a trustworthy
%   count. Do not wire its output into the 4-2-1 rule or any clinical
%   decision without real validation first.
%
%   Method: same dark-structure enhancement as segmentVessels (CLAHE +
%   morphological-close background estimate + subtract + threshold), then
%   subtract the known vessel mask and filter remaining blobs by size and
%   roundness. Two failure modes found and fixed during development,
%   consistent with other Module 2 functions: the field boundary produces
%   vignetting-driven false positives (fixed with the same interior-erosion
%   trick as disc/fovea localization), and a lenient threshold picks up
%   natural pigmentation texture as false positives (fixed by raising the
%   threshold multiplier and requiring stricter roundness).

REF_SIZE = size(img, 1);
green = im2double(img(:, :, 2));

enhanced = adapthisteq(green, 'ClipLimit', 0.008, 'NumTiles', [8 8]);
bg = imclose(enhanced, strel('disk', 9));
darkResponse = imsubtract(bg, enhanced);

equivRadius = sqrt(sum(fovMask(:)) / pi);
interiorMask = imerode(fovMask, strel('disk', round(equivRadius * 0.08)));
darkResponse(~interiorMask) = 0;

dthresh = graythresh(darkResponse(interiorMask)) * 1.5;
darkMask = darkResponse > dthresh;

candidateMask = darkMask & ~imdilate(vesselMask, strel('disk', 3)) & interiorMask;
candidateMask = bwareaopen(candidateMask, 2);

cc = bwconncomp(candidateMask);
stats = regionprops(cc, 'Eccentricity', 'EquivDiameter', 'Centroid');

% MA-like: small (a few pixels across at REF_SIZE=600) and roughly round,
% to reject the elongated vessel-fragment and larger-blob (hemorrhage-like)
% candidates that survive the vessel-mask subtraction.
isMA = arrayfun(@(s) s.EquivDiameter >= 2 && s.EquivDiameter <= 8 && s.Eccentricity < 0.85, stats);
maStats = stats(isMA);

result.count = numel(maStats);
if isempty(maStats)
    result.centroids = zeros(0, 2);
else
    result.centroids = reshape([maStats.Centroid], 2, [])';
end

end
