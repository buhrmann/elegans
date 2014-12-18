function [outsegImg, threImg] = watershedSeg3d62(segImg, inimg, idx, rgnMinSize, rgnConvexity, threImg, imgproptag, method,rgnMaxSize)
% function [outsegImg, threImg] = watershedSeg3d62(segImg, inimg, idx, rgnMinSize, rgnConvexity, threImg, imgproptag, method,rgnMaxSize)
%
% segment areas using geometry-based watershed segmentation and
% region grouping
% 
% Copyright F. Long
% Aug.27, 2006
%

outsegImg = segImg;
outsegImg(:) = 0;
sz = size(segImg);
stat = regionprops(segImg, 'PixelIdxList'); 
a = segImg;


for i=1:length(idx)

    
    % -----------------------
    % watershed segmentation
    % -----------------------
    
    a(:) = 0;
    a(stat(idx(i)).PixelIdxList) = 1;    
    % [i, length(idx), nnz(a)]
    
    [a1, xxmin, yymin, zzmin] = extractCube_FL2(a, stat(idx(i)).PixelIdxList);

    yrange = [max(1, yymin+1-2): min(sz(1), yymin+size(a1,1)+2)];
    xrange = [max(1, xxmin+1-2): min(sz(2), xxmin+size(a1,2)+2)];
    zrange = [max(1, zzmin+1-2): min(sz(3), zzmin+size(a1,3)+2)];    

    argn = uint16(a(yrange, xrange, zrange));    
    inimgrgn = uint16(inimg(yrange, xrange, zrange));    
    

    
    thre0 = threImg(stat(idx(i)).PixelIdxList(1)); 

    [f,thre] = rgnWatershed62(argn,inimgrgn,thre0, imgproptag,method); % watershed segmentation
    
    % ------------------------------------------
    % merge regions that should not be separated
    % ------------------------------------------
     
    rgnnum = max(f(:));        
   
    if (rgnnum>1) %otherwise, there is no need to merge
         f = rgnMerge80_2(f, inimgrgn, rgnConvexity, rgnMaxSize);          
    end; %if (rgnnum>1) end
    
    
    % ----------------------------------
    % dilate & assign labels to segmented regios
    % ----------------------------------
    
    if (nnz(f)>0)
        
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

       % generate threshold image

        threImg(stat(idx(i)).PixelIdxList) = thre;
        
        % assign label
        a(:) = 0;
        a(yrange, xrange, zrange) = f;
        outsegImg(a>0) = max(outsegImg(:)) + a(a > 0);
    else % keep the old segmentation mask unchanged
        labelval = max(outsegImg(:)) + 1;
        outsegImg(a>0) = labelval;        
    end;
  
end;

