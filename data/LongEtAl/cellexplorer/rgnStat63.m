function [rgn, labelimgnew] = rgnStat63(inimg, labelimg, threMinSize)        
%  function [rgn, labelimgnew] = rgnStat63(inimg, labelimg, threMinSize)        
% % compute region properties
%
% Copyright Fuhui Long
% Nov.16, 2006

labelimgnew = labelimg; 
labelimgnew(:) = 0;

stat = regionprops(labelimg,'Area', 'PixelIdxList');

idx = find([stat.Area]>threMinSize);
num = length(idx);
rgn = [];

sz = size(labelimg);
tmp = labelimg; 

for i= 1:num
        
    rgn(i,1) = stat(idx(i)).Area;

    tmp(:) = 0; 
    tmp(stat(idx(i)).PixelIdxList) = 1; 
    
    rgnCube = extractCube(tmp, stat(idx(i)).PixelIdxList); 
    rgnCube = uint16(rgnCube>0);
    rgn(i,2) = convexRatio2(rgnCube);
       
    labelimgnew(stat(idx(i)).PixelIdxList) = i;
        
end;

