function outsegImg = watershedSeg3d2(segImg, inimg, idx, rgnMinSize, rgnConvexityLow, threRatio)
% function outsegImg = watershedSeg3d2(segImg, inimg, idx, rgnMinSize,rgnConvexityLow, threRatio)
% 
% Region segmentation using watershed algorithm and region grouping
% 
% Copyright F. Long
% Apr.10, 2006


outsegImg = segImg;
outsegImg(:) = 0;
sz = size(segImg);
stat = regionprops(segImg, 'PixelIdxList'); 

for i=1:length(idx)

    a = segImg;
    a(:) = 0;
     a(stat(idx(i)).PixelIdxList) = 1;    
%     [i, length(idx), nnz(a)]
    
    [a1, xxmin, yymin, zzmin] = extractCube_FL2(a, stat(idx(i)).PixelIdxList);

    yrange = [max(1, yymin+1-2): min(sz(1), yymin+size(a1,1)+2)];
    xrange = [max(1, xxmin+1-2): min(sz(2), xxmin+size(a1,2)+2)];
    zrange = [max(1, zzmin+1-2): min(sz(3), zzmin+size(a1,3)+2)];    

    argn = uint16(zeros(length(yrange), length(xrange), length(zrange)));
    argn = uint16(a(yrange, xrange, zrange));    

    inimgrgn = uint16(inimg(yrange, xrange, zrange));    
    
   [f, thre] = rgnWatershed62(argn, inimgrgn, 0,0,5); % watershed segmentation
    
     
    rgnnum = max(f(:));        
   
    if (rgnnum>1) 
       f = rgnMerge3(f, inimgrgn, rgnMinSize, rgnConvexityLow, threRatio); % merge
    end; 
        
    % make label continous
    count = 0;
    g = f;
    g(:) = 0;

    rgnnum = max(f(:));

    ss = regionprops(f,'Area', 'PixelIdxList');
    iii = find([ss.Area]>0);
    
    for j=1:length(iii)
        g(ss(iii(j)).PixelIdxList) = j;
    end;
    
    f = g;
    a(yrange, xrange, zrange) = f;
    outsegImg(a>0) = max(outsegImg(:)) + a(a > 0);
  
end;

