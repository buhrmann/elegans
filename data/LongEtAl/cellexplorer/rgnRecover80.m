function [segImgnew, foundflg] = rgnRecover80(inimg, segImg)
% function [segImgnew, foundflg] = rgnRecover80(inimg, segImg)

% recover missing nuclei, this function should only be called when segImg,
% the intial segmentation is obtained. 
%
% Copyright Fuhui Long
% Aug 15, 2008

% ----------------------------------
% find candidate positions
% ----------------------------------

se1 = strel('disk',1);
se2 = strel('disk',2);
se3 = strel('disk',3);

% estimate background level

thre = graythresh(inimg(segImg==0))*255;

segImgdilate = permute(imdilate(permute(imdilate(segImg, se2), [1 3 2]), se2), [1 3 2]);
inimg2 = inimg.*uint8(segImgdilate==0);

remainimg = inimg2>thre;
dip_image(remainimg);

% rectify shape

aaa = permute(imopen(permute(imopen(remainimg,se2),[1 3 2]),se2), [1 3 2]); 
dip_image(aaa);

aaa = uint8(gaussf(aaa,1));
bbb = bwlabeln(aaa);

dip_image(bbb);

% select regions contain nuclei

if (nnz(bbb)>0)
    
    [rgn, ccc] = rgnStat3(inimg, bbb, 0, 1,1);
    ss1 = regionprops(segImg, 'Area');
    mediansz = median([ss1.Area]);

    egidx = find(rgn(:,3)>0.3); 
    szidx = find((rgn(:,1)>mediansz/2)&(rgn(:,1)<mediansz*3)); 
    cvidx = find(rgn(:,3)>0.6);

    id = intersect(intersect(egidx, szidx),cvidx);

    tt = uint16(segImg);
    tt(:) = 0;

    idnum = length(id);

    ss2 = regionprops(bbb, 'PixelIdxList');

    for i=1:idnum
        tt(ss2(id(i)).PixelIdxList) = id(i);
    end;

    dip_image(tt);
else
    idnum = 0;
end;
    

% -------------
% refine shapes
% -------------

segImgnew = segImg;
foundflg = 0;


if (idnum>=1) 
    foundflg = 1;

    segImgnew = (max(segImg(:)) + tt) .* uint16(tt>0) .* uint16(segImg==0) + uint16(segImg); 
end;

