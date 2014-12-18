function [rgn, labelimgnew] = rgnStat8(inimg, labelimg, threMinSize, convextag, elongationtag)
% function [rgn, labelimgnew] = rgnStat8(inimg, labelimg, threMinSize, convextag, elongationtag)        
% compute region properties
% Copyright F. Long
% July 21, 2008

% rgnSeg(:,1) --- size
% rgnSeg(:,2) --- convexity
% rgnSeg(:,3) ---  ratio between the first and the third biggest variance
% rgnSeg(:,4:6) --- the first three biggest eign values, different from major axes
% rgnSeg(:,7:9) --- x,y,z of the centroid
% rgnSeg(:,10:12) --- x,y,z dimension size


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

for i= 1:num
    
    rgn(i,1) = stat(idx(i)).Area;

    tmp(:) = 0; 
    tmp(stat(idx(i)).PixelIdxList) = 1; 

    if ((convextag == 1) &(elongationtag == 1))
        rgnCube = extractCube(tmp, stat(idx(i)).PixelIdxList); 
        rgnCube = uint16(rgnCube>0);
        rgn(i,10) = size(rgnCube,2); % x dimension
        rgn(i,11) = size(rgnCube,1); % y dimension 
        rgn(i,12) = size(rgnCube,3); % z dimension
        
    end;
    

    if (convextag == 1)
        rgn(i,2) = convexRatio2(rgnCube);
        
    end;


    if (elongationtag == 1)
        
        ind = find(rgnCube);
        
        if ndims(rgnCube) == 2
            covm = cov_grayimg2d(rgnCube, ind);
            [V,D] = eigs(covm);

            rgn(i,3) = D(1,1)/D(2,2); % the ratio between the first major orientation and the third major orientation 
            rgn(i,4) = D(1,1);
            rgn(i,5) = D(2,2);
            rgn(i,6) = D(2,2);
            
        else
            covm = cov_grayimg3d(rgnCube, ind);
            [V,D] = eigs(covm);

            rgn(i,3) = D(1,1)/D(3,3); % the ratio between the first major orientation and the third major orientation 
            rgn(i,4) = D(1,1);
            rgn(i,5) = D(2,2);
            rgn(i,6) = D(3,3);
        end;
        
    end;
    
    labelimgnew(stat(idx(i)).PixelIdxList) = i;
        
end;


stat = regionprops(labelimgnew, 'Centroid');

tt = [stat.Centroid];
len = length(tt);

rgn(:,7) = tt(1:3:len);
rgn(:,8) = tt(2:3:len);
rgn(:,9) = tt(3:3:len);

