function enhanced = enhanceImage(img)
%ENHANCEIMAGE Apply CLAHE, illumination normalization, and denoising to
%   a borderline-quality fundus image.
%
%   enhanced = ENHANCEIMAGE(img) returns an enhanced RGB image, same
%   class and size as the input.

wasUint8 = isa(img, 'uint8');
rgb = im2double(img);

% 1. Illumination normalization: divide by a heavily blurred version of
%    the luminance channel to flatten large-scale shading gradients
%    (common with off-axis or poorly-lit fundus captures).
hsv = rgb2hsv(rgb);
v = hsv(:, :, 3);
background = imgaussfilt(v, 31);
background(background < 0.05) = 0.05; % avoid division blow-up
vFlat = v ./ background;
vFlat = vFlat * mean(background(:));
vFlat = min(max(vFlat, 0), 1);
hsv(:, :, 3) = vFlat;
rgb = hsv2rgb(hsv);

% 2. CLAHE on the luminance channel for local contrast enhancement,
%    applied via LAB to avoid color-channel artifacts.
lab = rgb2lab(rgb);
L = lab(:, :, 1) / 100;
L = adapthisteq(L, 'ClipLimit', 0.01, 'NumTiles', [8 8]);
lab(:, :, 1) = L * 100;
rgb = lab2rgb(lab);
rgb = min(max(rgb, 0), 1);

% 3. Denoise: edge-preserving bilateral filter per channel to suppress
%    sensor/compression noise from low-cost portable fundus cameras
%    without blurring vessel and lesion boundaries.
for c = 1:3
    rgb(:, :, c) = imbilatfilt(rgb(:, :, c), 0.01, 3);
end

if wasUint8
    enhanced = im2uint8(rgb);
else
    enhanced = rgb;
end

end
