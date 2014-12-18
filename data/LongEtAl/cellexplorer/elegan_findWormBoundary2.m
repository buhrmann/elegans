function c12 = elegan_findWormBoundary2(a, id_gfp, id_dapi)
%function c12 = elegan_findWormBoundary2(a, id_gfp, id_dapi)
%
% find worm boundary
%
% Copyright Fuhui Long & Hanchuan Peng
% 20051103, 20051129


% project to XY plane
projDirection = 3; 

wormImg = uint8(a);
proj1 = projWormTo2D(wormImg, projDirection);
proj1 = proj1/max(proj1(:))*255;

close all;



a1 = proj1(:,:,id_gfp);
b1 = medfilt2(uint8(a1));
dip_image(b1)


a2 = proj1(:,:,id_dapi); 
b2 = medfilt2(uint8(a2));
dip_image(b2)

% add DAPI and GFP channel and median filtering
a12 = proj1(:,:,id_gfp) + proj1(:,:,id_dapi);
a12 = a12/max(a12(:))*255; 
b12 =  medfilt2(uint8(a12));
dip_image(b12)

nn = histc(b12(:),[0:255]);
[maxval, idxval] = max(nn(:));
thre = idxval;
 c12 = (b12>thre+2);
dip_image(c12)

c12 = medfilt2(c12);
c12label = bwlabel(c12);
dip_image(c12label)

% remove small regions and regions that touch the worm body
for i=1:max(c12label(:))
    objSize(i) = nnz(c12label==i);
end;

[maxObj, maxidx] = max(objSize);
c12label = (c12label==maxidx);
se = strel('disk',5,0);
c12eroded = imerode(c12label,se);
dip_image(c12eroded)

c12 = c12eroded;

