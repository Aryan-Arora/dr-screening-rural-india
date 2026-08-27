function result = detectExudates(img, vesselMask, fovMask, discCenter, discRadius)
%DETECTEXUDATES Classical-CV hard exudate candidate detection.
%   result = DETECTEXUDATES(img, vesselMask, fovMask, discCenter, discRadius)
%   returns a struct:
%       count      - number of exudate-like candidates found
%       centroids  - Nx2 [x y] candidate locations, REF_SIZE coordinates
%       totalArea  - total candidate pixel area (rough lesion burden proxy)
%       mask       - logical REF_SIZE x REF_SIZE candidate mask (useful
%                    for excluding exudate regions in other detectors --
%                    a dark-structure detector run near exudates otherwise
%                    misreads their shadowed edges as separate lesions)
%
%   img/vesselMask/fovMask/discCenter/discRadius match segmentVessels and
%   localizeOpticDisc's outputs (same REF_SIZE x REF_SIZE space).
%
%   Same validation caveat as detectMicroaneurysms.m: NOT checked against
%   pixel-level ground truth. Unlike microaneurysms, though, this got a
%   real positive signal during development -- on a sample with visible
%   bright yellow-white deposits near the macula, candidates clustered
%   tightly on the visible lesion; on visually "healthy" samples, false
%   positives were traceable to specific, fixed causes (see below) rather
%   than random noise. Still first-pass; still not a validated count.
%
%   Method: white top-hat (bright structures smaller than the structuring
%   element vs. local background) on the CLAHE-enhanced green channel --
%   the polarity opposite of vessel/MA detection, since exudates are
%   bright, not dark. Two false-positive sources found and excluded:
%     1. The optic disc is the brightest thing in the frame and swamps a
%        naive bright-blob threshold. A simple radius-based exclusion
%        undershot it at first -- the peripapillary region (where vessels
%        converge and light scatters near the disc margin) is bright well
%        beyond the disc's own boundary, needing a much wider exclusion
%        (3.5x disc radius, vs. 1.8x initially) than the disc itself.
%     2. Vessel walls (especially arterioles) carry a bright central
%        reflex/highlight that reads as a string of bright "lesions"
%        tracing every vessel -- excluded via the same dilated vessel
%        mask used elsewhere in this module.

REF_SIZE = size(img, 1);
green = im2double(img(:, :, 2));
enhanced = adapthisteq(green, 'ClipLimit', 0.008, 'NumTiles', [8 8]);

brightResponse = imtophat(enhanced, strel('disk', 15));
brightResponse(~fovMask) = 0;

equivRadius = sqrt(sum(fovMask(:)) / pi);
interiorMask = imerode(fovMask, strel('disk', round(equivRadius * 0.08)));

[X, Y] = meshgrid(1:REF_SIZE, 1:REF_SIZE);
discExclude = (X - discCenter(1)).^2 + (Y - discCenter(2)).^2 <= (discRadius * 3.5)^2;
vesselExclude = imdilate(vesselMask, strel('disk', 4));

bthresh = graythresh(brightResponse(interiorMask)) * 1.8;
brightMask = brightResponse > bthresh & interiorMask & ~discExclude & ~vesselExclude;
brightMask = bwareaopen(brightMask, 8); % exudates are bigger than MAs

cc = bwconncomp(brightMask);
stats = regionprops(cc, 'Area', 'Centroid');

result.count = numel(stats);
result.totalArea = sum([stats.Area]);
result.mask = brightMask;
if isempty(stats)
    result.centroids = zeros(0, 2);
else
    result.centroids = reshape([stats.Centroid], 2, [])';
end

end
