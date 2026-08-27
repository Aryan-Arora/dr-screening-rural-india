function result = localizeFovea(img, vesselMask, fovMask, discCenter, discRadius)
%LOCALIZEFOVEA Classical-CV fovea localization.
%   result = LOCALIZEFOVEA(img, vesselMask, fovMask, discCenter, discRadius)
%   returns a struct:
%       center     - [x y] fovea center, in REF_SIZE x REF_SIZE coordinates
%       confidence - 'high' | 'low'
%
%   img/vesselMask/fovMask must be in the same REF_SIZE x REF_SIZE space
%   as segmentVessels/localizeOpticDisc output. discCenter/discRadius come
%   from localizeOpticDisc.
%
%   Method: the fovea appears as a subtle local reflectance dip, roughly
%   1.5-4.5 disc-diameters from the disc center and away from major
%   vessels. Two failure modes had to be corrected during development:
%     1. Raw "darkest pixel" search is dominated by vignetting, which
%        darkens gradually toward every frame edge regardless of anatomy
%        -- it kept finding the image border, not the fovea. Fixed by
%        dividing by a heavily-blurred version of the same channel
%        (flattens the large-scale illumination gradient) before
%        searching, same trick as enhanceImage.m's illumination step.
%     2. Even flattened, a search with no anatomical prior will happily
%        return a point that isn't the fovea at all when foveal contrast
%        is genuinely weak in a given capture. Confidence is therefore
%        based on how deep the found dip actually is, not just whether a
%        minimum was found (a minimum always exists somewhere).

REF_SIZE = size(img, 1);
vesselExclude = imdilate(vesselMask, strel('disk', 6));

equivRadius = sqrt(sum(fovMask(:)) / pi);
interiorMask = imerode(fovMask, strel('disk', max(1, round(equivRadius * 0.1))));

[X, Y] = meshgrid(1:REF_SIZE, 1:REF_SIZE);
distFromDisc = hypot(X - discCenter(1), Y - discCenter(2));
discDiameter = 2 * discRadius;
band = distFromDisc >= 1.5 * discDiameter & distFromDisc <= 4.5 * discDiameter;
candidateRegion = interiorMask & ~vesselExclude & band;

lum = im2double(img(:, :, 2));
background = imgaussfilt(lum, 45);
flat = lum ./ max(background, 0.05);
flatSmooth = imgaussfilt(flat, 10);

searchVal = flatSmooth;
searchVal(~candidateRegion) = Inf;

if ~any(candidateRegion(:))
    % No plausible region at all (e.g. disc localization was unreliable) --
    % fall back to the whole interior, minus vessels, and flag low
    % confidence rather than guessing inside the exclusion band.
    searchVal = flatSmooth;
    searchVal(~(interiorMask & ~vesselExclude)) = Inf;
    fallback = true;
else
    fallback = false;
end

[minVal, idx] = min(searchVal(:));
[fy, fx] = ind2sub(size(searchVal), idx);

% Calibrated against 4 real samples: a genuine foveal dip reads well below
% 1.0 (relative to the flattened local background); the one miss observed
% during development sat at 0.84, indistinguishable from background.
FOVEA_CONTRAST_MAX = 0.80;
if fallback || minVal > FOVEA_CONTRAST_MAX
    confidence = 'low';
else
    confidence = 'high';
end

result.center = [fx, fy];
result.confidence = confidence;
result.contrast = minVal;

end
