function result = segmentVessels(img)
%SEGMENTVESSELS Classical-CV retinal vessel segmentation.
%   result = SEGMENTVESSELS(img) returns a struct:
%       mask       - logical REF_SIZE x REF_SIZE vessel mask
%       density    - fraction of the retinal field covered by vessels
%       fovMask    - the retinal field mask segmentation was restricted to
%
%   Method: CLAHE on the green channel (best vessel/background contrast),
%   morphological closing to estimate the vessel-free local background,
%   subtract to get a vessel-enhanced response (a black top-hat by another
%   name), then threshold and clean small speckle. Standard classical
%   pipeline for this task; no learned model involved.

REF_SIZE = 600;
img = imresize(img, [REF_SIZE, REF_SIZE]);

gray = im2double(rgb2gray(img));
level = max(graythresh(gray), 0.03);
fovMask = imbinarize(gray, level);
fovMask = imfill(fovMask, 'holes');
fovMask = bwareafilt(fovMask, 1);
if ~any(fovMask(:))
    fovMask = true(size(gray));
end

green = im2double(img(:, :, 2));
enhanced = adapthisteq(green, 'ClipLimit', 0.008, 'NumTiles', [8 8]);
background = imclose(enhanced, strel('disk', 9));
vesselResponse = imsubtract(background, enhanced);
vesselResponse(~fovMask) = 0;

% Otsu's threshold on the response, scaled up slightly -- straight Otsu
% pulls in too much low-contrast background noise for this task.
vthresh = graythresh(vesselResponse(fovMask)) * 1.3;
mask = vesselResponse > vthresh;
mask = bwareaopen(mask, 15) & fovMask;

result.mask = mask;
result.density = sum(mask(:)) / sum(fovMask(:));
result.fovMask = fovMask;

end
