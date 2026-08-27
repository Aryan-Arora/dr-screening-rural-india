function result = segmentStructures(img)
%SEGMENTSTRUCTURES Module 2 entry point: vessel segmentation + optic
%   disc/fovea localization on a quality-gated fundus image.
%
%   result = SEGMENTSTRUCTURES(img) returns a struct:
%       vessels        - struct from segmentVessels (mask, density, fovMask)
%       disc           - struct from localizeOpticDisc (center, radius, confidence)
%       fovea          - struct from localizeFovea (center, confidence)
%       microaneurysms - struct from detectMicroaneurysms (count, centroids)
%                        -- UNVALIDATED, see detectMicroaneurysms.m
%       exudates       - struct from detectExudates (count, centroids, totalArea, mask)
%                        -- also unvalidated, see detectExudates.m
%       hemorrhages    - struct from detectHemorrhages (count, centroids)
%                        -- also unvalidated, see detectHemorrhages.m
%
%   img should be the image accepted/enhanced by Module 1's qualityGate.
%   All outputs are in a common REF_SIZE x REF_SIZE (600x600) coordinate
%   space regardless of img's native resolution.
%
%   Priority per PRD: optic disc/fovea localization and vessel
%   segmentation are full, validated implementations. Microaneurysm
%   detection is a first-pass, unvalidated candidate detector (no
%   ground-truth lesion annotations available -- see its own file).
%   Exudate segmentation, hemorrhage classification, and neovascularization
%   detection are not yet started.

vessels = segmentVessels(img);

REF_SIZE = size(vessels.mask, 1);
imgResized = imresize(img, [REF_SIZE, REF_SIZE]);

disc = localizeOpticDisc(imgResized, vessels.mask, vessels.fovMask);
fovea = localizeFovea(imgResized, vessels.mask, vessels.fovMask, disc.center, disc.radius);
microaneurysms = detectMicroaneurysms(imgResized, vessels.mask, vessels.fovMask);
exudates = detectExudates(imgResized, vessels.mask, vessels.fovMask, disc.center, disc.radius);
hemorrhages = detectHemorrhages(imgResized, vessels.mask, vessels.fovMask, disc.center, disc.radius, fovea.center, exudates.mask);

result.vessels = vessels;
result.disc = disc;
result.fovea = fovea;
result.microaneurysms = microaneurysms;
result.exudates = exudates;
result.hemorrhages = hemorrhages;

end
