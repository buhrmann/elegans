function proj = projWormTo2D(wormImg, projDirection)

figure; 
for channel=1:size(wormImg,4)
     proj(:,:,channel) = sum(wormImg(:,:,:,channel),projDirection);
     %080804: seem the following modification does not work
%     proj(:,:,channel) = max(wormImg(:,:,:,channel),[], projDirection); 
    subplot(2,2,channel); imagesc(squeeze(proj(:,:,channel))); 
end;



