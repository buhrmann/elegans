function convexR = convexRatio2(rgnimg)
% function convexR = convexRatio2(rgnimg)
% 
% Compute the convexity of rgnimg using a 2D approach
%
% Copyright Fuhui Long

sz1 = size(rgnimg,1);
sz2 = size(rgnimg,2);
sz3 = size(rgnimg,3);

convexRgnArea = 0;
for i=1:sz1
    tmp = squeeze(rgnimg(i,:,:));
    if (nnz(tmp)>0)
        stat = regionprops(tmp, 'ConvexHull');
        convexRgnArea = convexRgnArea + nnz(roipoly(tmp, stat(1).ConvexHull(:,1), stat(1).ConvexHull(:,2)));
    end;
end;
r(1) = nnz(rgnimg) / convexRgnArea;

convexRgnArea = 0;
for i=1:sz2
    tmp = squeeze(rgnimg(:,i,:));
    if (nnz(tmp)>0)
        stat = regionprops(tmp, 'ConvexHull');
        convexRgnArea = convexRgnArea + nnz(roipoly(tmp, stat(1).ConvexHull(:,1), stat(1).ConvexHull(:,2)));
    end;
end;
r(2) = nnz(rgnimg)/convexRgnArea ;

convexRgnArea = 0;
for i=1:sz3
    tmp = squeeze(rgnimg(:,:,i));
    if (nnz(tmp)>0)
        stat = regionprops(tmp, 'ConvexHull');
        convexRgnArea = convexRgnArea + nnz(roipoly(tmp, stat(1).ConvexHull(:,1), stat(1).ConvexHull(:,2)));
    end;
end;
r(3) = nnz(rgnimg)/convexRgnArea;


convexR = min(r);
