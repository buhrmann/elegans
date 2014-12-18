function main_genWebData_DAPI(inimg, segimg, targetdir, channelID)
% function main_genWebData_DAPI(inimg, segimg, targetdir, channelID)
% 
% Generate data for annotation
% inimg --- 4D image (not in dip-image format)
% segimg --- segmented result of a particular channel
% targetdir --- target directory under which the data is saved
% channelID ---- particular channel for annotation


inimg_channel = dip_image(squeeze(inimg(:,:,:,channelID)));
outimg_label = dip_image(segimg);

inimg_color = inimg;
inimg_color(:,:,:,3) = 0;

batch_save2web(inimg_channel, outimg_label, targetdir, inimg_color) %inimg_color is not used by batch_save2web

