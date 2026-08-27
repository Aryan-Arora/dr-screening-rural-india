function result = localizeOpticDisc(img, vesselMask, fovMask)
%LOCALIZEOPTICDISC Classical-CV optic disc localization.
%   result = LOCALIZEOPTICDISC(img, vesselMask, fovMask) returns a struct:
%       center     - [x y] disc center, in REF_SIZE x REF_SIZE coordinates
%       radius     - estimated disc radius in pixels
%       confidence - 'high' | 'low'
%
%   img must already be resized to REF_SIZE x REF_SIZE (as done by
%   segmentVessels), and vesselMask/fovMask must be its outputs, so the
%   two functions agree on coordinates.
%
%   Method: the disc is the brightest large connected region in the red
%   channel, away from the field boundary (excluding the rim avoids
%   locking onto lens-glare/vignette artifacts near the edge, which are
%   otherwise the single biggest failure mode on field-quality captures).
%   Confidence is a physical sanity check, not a second localizer: the
%   disc is where the major vessel arcades originate, so if the candidate
%   location has almost no vessels nearby, something's wrong (glare,
%   reflection) and the result is flagged low-confidence rather than
%   silently returned as if it were reliable.

REF_SIZE = size(img, 1);
equivRadius = sqrt(sum(fovMask(:)) / pi);
searchMask = imerode(fovMask, strel('disk', max(1, round(equivRadius * 0.12))));

red = im2double(img(:, :, 1));
smoothed = imgaussfilt(red, 15);
smoothed(~searchMask) = -Inf;
[maxVal, maxIdx] = max(smoothed(:));
[cy, cx] = ind2sub(size(smoothed), maxIdx);

candidate = smoothed >= maxVal * 0.85 & searchMask;
candidate = bwlabel(candidate);
discMask = candidate == candidate(cy, cx);
radius = sqrt(sum(discMask(:)) / pi);

% Confidence check: sample vessel coverage in a window around the
% candidate, sized generously relative to the estimated disc.
checkRadius = max(radius * 1.8, REF_SIZE * 0.04);
[X, Y] = meshgrid(1:REF_SIZE, 1:REF_SIZE);
localWindow = (X - cx).^2 + (Y - cy).^2 <= checkRadius^2;
localVesselFraction = sum(vesselMask(localWindow)) / sum(localWindow(:));

LOCAL_VESSEL_MIN = 0.05; % calibrated against 15 real APTOS samples: real
                          % discs land at 0.10-0.21, a lens-glare false
                          % positive landed at 0.00.
if localVesselFraction < LOCAL_VESSEL_MIN
    confidence = 'low';
else
    confidence = 'high';
end

result.center = [cx, cy];
result.radius = radius;
result.confidence = confidence;
result.local_vessel_fraction = localVesselFraction;

end
