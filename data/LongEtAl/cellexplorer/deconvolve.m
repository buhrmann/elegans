function resimg1 = deconvolve(imgname, outimgname, channelID, psfSize)
% function resimg1 = deconvolve(imgname, outimgname, channelID, psfSize)
% This function is used to deconvolve the 3D image
%
% Copyright: F. Long
% 20060418


fprintf('Deconvolve image stack, please wait ....\n');

img = uint8(readim(imgname)); % read original image
img_ori = double(squeeze(img(:,:,:,channelID))); 

dip_image(img_ori);

sz = size(img_ori);
szmin = min([sz(1),sz(2),sz(3)]);


% YZ plane
resimg1 = zeros(sz); 
PSF = fspecial('gaussian',szmin,20);

for i=1:sz(2)
%     i
    [nn1,nn2] = deconvblind(squeeze(img_ori(:,i,:)),PSF);
    resimg1(:,i,:) = nn1;
end;

dip_image(resimg1);

% XZ plane
resimg2 = zeros(sz);

PSF = fspecial('gaussian',szmin,20);

for i=1:sz(1)
%     i
    [nn1,nn2] = deconvblind(squeeze(img_ori(i,:,:)),PSF);
    resimg2(i,:,:) = nn1;
end;

dip_image(resimg2);

% average
resimg1 = (resimg1+resimg2)/2;
dip_image(resimg1);

writeim(resimg1,outimgname,'ics');

