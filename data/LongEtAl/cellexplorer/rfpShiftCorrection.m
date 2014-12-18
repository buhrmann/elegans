function [outimg,dis] = rfpShiftCorrection(filename, id_rfp, id_dapi)
% function [outimg,dis] = rfpShiftCorrection(filename, id_rfp, id_dapi)
%
% correct the rfp shift along Z direction
% 
% Copyright Fuhui Long & Hanchuan Peng
%
% 20070111


% ---------------------------
inimg = uint8(readim(filename));
rfpimg2d = (squeeze(sum(inimg(:,:,:,id_rfp),1)))';
dapiimg2d = (squeeze(sum(inimg(:,:,:,id_dapi),1)))';
 
rfpimg2d = rfpimg2d/max(rfpimg2d(:))*255;
dapiimg2d = dapiimg2d/max(dapiimg2d(:))*255;
 
meanval = mean(rfpimg2d(rfpimg2d>0));
stdval = std(rfpimg2d(rfpimg2d>0));
rfpimg2d2 = rfpimg2d;
rfpimg2d2(rfpimg2d<(meanval+2*stdval)) = 0;

% ---------------------------

len = size(rfpimg2d,1);


count = 0;
wid = 10;

for z=-wid:0

    shiftRfpImg = rfpimg2d2;
    shiftRfpImg(:) = 0;
    
    cord1 = [max(1,1+z):min(len,len+z)];
    cord2 = [max(1,1-z):min(len,len-z+1)];
    
    shiftRfpImg(cord1,:) = rfpimg2d2(cord2,:);
    
    count = count + 1;
    shiftEval(count) = sum(sum(shiftRfpImg .* dapiimg2d));
    
end;

for z=1:wid
    
    shiftRfpImg = rfpimg2d2;
    shiftRfpImg(:) = 0;
    
    cord1 = [max(1,1+z):min(len,len+z)];
    cord2 = [max(1,1-z):min(len,len-z)];
    
    shiftRfpImg(cord1,:) = rfpimg2d2(cord2,:);

    count = count + 1;
    shiftEval(count) = sum(sum(shiftRfpImg .* dapiimg2d));
end;

% ------------------

[maxval, maxidx] = max(shiftEval);
shift0 = (length(shiftEval)+1)/2;
dis = maxidx-shift0;

dis0 = dis;

stoptag = 0;

while (stoptag == 0)

    joinchannels('rgb', inimg(:,:,:,id_rfp), inimg(:,:,:,id_dapi))

    fprintf('Computer suggested shift = %d pixels\n', dis0);
    fprintf('Shifts in the following figures are %d, %d, %d, %d, %d pixels\n', dis-2, dis-1, dis, dis+1, dis+2);
    
    for mydis=dis-2:dis+2

        outimg = inimg;

        cord1 = [max(1,1+mydis):min(len,len+mydis)];
        cord2 = [max(1,1-mydis):min(len,len-mydis)];
        outimg(:,:,cord1,1) = inimg(:,:,cord2,1);
        
        joinchannels('rgb', outimg(:,:,:,id_rfp), outimg(:,:,:,id_dapi))

    end;

    dis2 = input('Enter pixel shift (press return to accept computer suggested value, or input a new prefered value)\n');

    if isempty(dis2)
        dis2 = dis0;
    end;

    if (dis2>=dis-2)&(dis2<=dis+2) % select new values
        stoptag = 1;
    end;

    dis = dis2;
   
    close all;
end;
    
    
%----------------    

outimg = inimg;

cord1 = [max(1,1+dis):min(len,len+dis)];
cord2 = [max(1,1-dis):min(len,len-dis+1)];
outimg(:,:,cord1,1) = inimg(:,:,cord2,1);
    
    
