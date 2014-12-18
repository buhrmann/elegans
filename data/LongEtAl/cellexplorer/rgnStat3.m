function [rgn, labelimgnew] = rgnStat3(inimg, labelimg, threMinSize, convextag, elongationtag)
% function [rgn, labelimgnew] = rgnStat3(inimg, labelimg, threMinSize, convextag, elongationtag)        
% 
% compute region properties
% Copyright F. Long
% latest update 20061026

labelimgnew = labelimg; 
labelimgnew(:) = 0;

stat = regionprops(labelimg,'Area', 'Centroid', 'PixelIdxList');

idx = find([stat.Area]>threMinSize);
num = length(idx);
rgn = [];

tt = inimg;
tt2 = inimg;

sz = size(labelimg);
tmp = labelimg; 

fprintf('computing statistics for regions. Total #regions = %d\n', num);
for i= 1:num,
    
    fprintf('%d ', i);
    if (mod(i,20)==0), fprintf('\n'); end;
    
    rgn(i,1) = stat(idx(i)).Area;

    tmp(:) = 0; 
    tmp(stat(idx(i)).PixelIdxList) = 1; 
    
    if (convextag == 1)
        rgnCube = extractCube(tmp, stat(idx(i)).PixelIdxList); 
        rgnCube = uint16(rgnCube>0);
        rgn(i,2) = convexRatio2(rgnCube);
    end;

    if (elongationtag == 1)
        rad = (rgn(i,1).^(1/3))/2;
        tt(:) = 0;
        tt(max(1, round(stat(idx(i)).Centroid(2)-rad)): min(round(stat(idx(i)).Centroid(2)+rad),sz(1)),...
           max(1, round(stat(idx(i)).Centroid(1)-rad)): min(round(stat(idx(i)).Centroid(1)+rad),sz(2)),...
           max(1, round(stat(idx(i)).Centroid(3)-rad)): min(round(stat(idx(i)).Centroid(3)+rad),sz(3))) = 1;         
        tt2(:) = 0;
        tt2(stat(idx(i)).PixelIdxList) = 1;
        rgn(i,3) = nnz(tt .* tt2)/rgn(i,1);
    end;
        
    labelimgnew(stat(idx(i)).PixelIdxList) = i;
        
end;
fprintf('\n');


