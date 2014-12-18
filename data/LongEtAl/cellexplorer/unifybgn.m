function correctImg = unifybgn(inimg)
% function correctImg = unifybgn(inimg)

% rectify non-uniform background
%
% Copyright F. Long
% 20060224

fprintf('Rectify non-uniform background, please wait ...\n');

se = strel('disk',25);

sz = size(inimg);

correctImg = inimg;
correctImg(:) = 0;

for i=1:sz(3)
    correctImg(:,:,i) = imtophat(inimg(:,:,i),se);
end;

