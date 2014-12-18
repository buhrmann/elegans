function c12 = elegan_manualFindWormBoundary(a, id_gfp, id_dapi) 
% function c12 = elegan_manualFindWormBoundary(a, id_gfp, id_dapi) 
% 
% Copyright Fuhui Long
% latest update 20061210

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

a12 = proj1(:,:,id_gfp) + proj1(:,:,id_dapi);
a12 = a12/max(a12(:))*255; 
b12 =  medfilt2(uint8(a12));
dip_image(b12)

[c12, CY, CX] = roipoly(b12);
CX = round(CX);
CY = round(CY);


imagesc(c12); 

ept.x = CX
ept.y = CY
rx = 1; ry = 1;
method = 'median';

ept1 = smooth_object_contour(ept, rx, ry, method);
c12 = roipoly(b12, ept1.y, ept1.x);


