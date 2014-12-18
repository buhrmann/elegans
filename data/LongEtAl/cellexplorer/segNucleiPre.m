function segNucleiPre(imgname, outimgnamedev, outimgnamepre, channelID,  psfSize)
% function segNucleiPre(imgname, outimgnamedev, outimgnamepre, channelID,  psfSize)

% preprocessing of image stacks, including deconvolution, gaussian
% smoothing, and non-uniform background removing
% 
% Copyright: F. Long
% 20060410


img = uint8(readim(imgname)); % read original image
img_ori = squeeze(img(:,:,:,channelID)); 


% deconvolve image
if (~isempty(outimgnamedev))
    resimg1 = deconvolve(imgname, outimgnamedev, channelID, psfSize);
else
    resimg1 = img_ori;
end;


% gaussian smoothing

inimg =  uint8(gaussf(resimg1,1)); 

% non-uniform background removing
inimg = unifybgn(inimg);


writeim(inimg,outimgnamepre,'ics');

