function [segImg2new, foundflg] = rgnMerge80(inimg, segImg2, rgnSeg, szratio)
% function [segImg2new, foundflg] = rgnMerge80(inimg, segImg2, rgnSeg, szratio)
%
% Copyright F. Long
% Aug 14, 2008

%-------------------------
% initialize parameters
%-------------------------

se1 = strel('disk', 1);
se2 = strel('disk', 2);

tt = segImg2;
tt(:) = 0;

sz = size(segImg2);

f = segImg2;
rgn_m = f;
rgn_mn = f;

ss = regionprops(f, 'Area', 'PixelIdxList');

mediansz = median(rgnSeg(:,1));


%-----------------------------------------------
% find small regions, do not consider convexity
%-----------------------------------------------

cvidx = find(rgnSeg(:,2)<1.1); 

szidx = find(rgnSeg(:,1)<(mediansz*szratio)); 
outlierIdx = intersect(cvidx,szidx);

stat2 = regionprops(segImg2, 'PixelIdxList');



outlierRgnMask = segImg2;
outlierRgnMask(:) = 0;

outlierRgnNum = length(outlierIdx);

for i=1:outlierRgnNum
    outlierRgnMask(stat2(outlierIdx(i)).PixelIdxList) = outlierIdx(i);
    
end;

% remove those at the margin
marginidx = union(unique(outlierRgnMask(:,1,:)),unique(outlierRgnMask(:,end,:)));
outlierIdx = setdiff(outlierIdx, marginidx);

for i=2:length(marginidx)
    outlierRgnMask(stat2(marginidx(i)).PixelIdxList) = 0;
end;    
    
outlierRgnNum = length(outlierIdx);

removeidx = [];

%-----------
% merge
%-----------


for m=1:outlierRgnNum
    
    
    if (ss(outlierIdx(m)).Area < 4)
        f(ss(outlierIdx(m)).PixelIdxList) = 0; 
    else

        % --------------------
        % compute initial r
        % --------------------
        
        r = [];

        rgn_m(:) = 0;
        rgn_m(ss(outlierIdx(m)).PixelIdxList) = 1;    


        [outcube,xxmin, yymin, zzmin] = extractCube_FL2(rgn_m, ss(outlierIdx(m)).PixelIdxList);

        % find neighborhood regions
        ystart = max(1, yymin-10); yend = min(sz(1), yymin+size(outcube,1)+10);
        xstart = max(1, xxmin-10); xend = min(sz(2), xxmin+size(outcube,2)+10);
        zstart = max(1, zzmin-10); zend = min(sz(3), zzmin+size(outcube,3)+10);
        
        a = rgn_m(ystart:yend, xstart:xend, zstart:zend);
        a_d = permute(imdilate(permute(imdilate(a, se1), [1 3 2]), se1), [1 3 2]); 
        b = f(ystart:yend, xstart:xend, zstart:zend);

        inimgrgn = inimg(ystart:yend, xstart:xend, zstart:zend);
        
        neighborRgnIdx = unique(a_d .* b); %neighbor regions of m
        neighborRgnIdx = setdiff(neighborRgnIdx, [0,outlierIdx(m)]); 
        
        [m, length(neighborRgnIdx)];

        mergetag = 0;
        
        if (~isempty(neighborRgnIdx))
            
            % -------  compute convexity vector -------
            for n =1:length(neighborRgnIdx)

                rgn_mn(:) = 0;
                rgn_mn([ss(outlierIdx(m)).PixelIdxList; ss(neighborRgnIdx(n)).PixelIdxList]) = 1;

                rgnCube = extractCube(uint8(rgn_mn), [ss(outlierIdx(m)).PixelIdxList; ss(neighborRgnIdx(n)).PixelIdxList]);
                
                
                [y1,x1,z1] = ind2sub(size(rgnCube), find(rgnCube>0));
                pt = [y1,x1,z1];
                [K,V] = convhulln(pt);
                r(n) = nnz(rgnCube)/V;                    
                
            end;
            
            % ------- merge -------
            
            labelvalold = outlierIdx(m);

            while (~isempty(r))
                
                
                [maxval, maxidx] = max(r);

                if (maxval>0.9)                    

                    labelval = neighborRgnIdx(maxidx);
                    sumarea = ss(labelvalold).Area + ss(labelval).Area;

                    if (sumarea < 2*mediansz)
                        
                        % merge
                        mergetag = 1;
                        
                        f(ss(labelval).PixelIdxList) = labelvalold;        
                        
                        ss(labelvalold).Area = sumarea; % recompute region size
                        ss(labelval).Area = 0;
                        
                        ss(labelvalold).PixelIdxList = [ss(labelvalold).PixelIdxList; ss(labelval).PixelIdxList];
                        ss(labelval).PixelIdxList =[];        
                                                
                        % recompute convexity 
                        
                        % find new neighbor
                        b = f(ystart:yend, xstart:xend, zstart:zend);
                        a(:) = 0;
                        a(b==labelval) = 1;
                        a_d = permute(imdilate(permute(imdilate(a, se1), [1 3 2]), se1), [1 3 2]); 

                        neighborRgnIdx = unique(a_d .* b); %neighbor regions of m
                        neighborRgnIdx = setdiff(neighborRgnIdx, [0,labelval]); % remove background, itself, and only compute upper triangle

                        
                        % compute convexity vector
                        r = [];
                        
                        for n =1:length(neighborRgnIdx)

                            rgn_mn(:) = 0;
                            rgn_mn([ss(labelval).PixelIdxList; ss(neighborRgnIdx(n)).PixelIdxList]) = 1;

                            rgnCube = extractCube(uint8(rgn_mn), [ss(labelval).PixelIdxList; ss(neighborRgnIdx(n)).PixelIdxList]);

                            [y1,x1,z1] = ind2sub(size(rgnCube), find(rgnCube>0));
                            pt = [y1,x1,z1];
                            [K,V] = convhulln(pt);
                            r(n) = nnz(rgnCube)/V;                    
                        end;
                                               
                        
                    else 
                        r(maxidx) = 0;
                    end; %if (sumarea < 2*mediansz)

                else
                    break; % stop merging
                end; %if (maxval>0.9)
                
            end; % while end
        end; % if (~isempty(neighborRgnIdx)) end
            
        if (mergetag == 0) % remove for later recover
            f(ss(outlierIdx(m)).PixelIdxList) = 0;
            removeidx = [removeidx; m];
            
        end;
        
    end; % if (ss(outlierIdx(m)).Area < 4) end
end; % for end

% ----------
% recover
% ----------

a = segImg2;

numi = length(removeidx);

for i=1:numi

    % extract region mask
    if (nnz(f(ss(outlierIdx(removeidx(i))).PixelIdxList))==0) 
        
        a(:) = 0;
        a(ss(outlierIdx(removeidx(i))).PixelIdxList) = 1;
        
        [a1, xxmin, yymin, zzmin] = extractCube_FL2(a, ss(outlierIdx(removeidx(i))).PixelIdxList);

        yrange = [max(1, yymin+1-15): min(sz(1), yymin+size(a1,1)+15)];
        xrange = [max(1, xxmin+1-15): min(sz(2), xxmin+size(a1,2)+15)];
        zrange = [max(1, zzmin+1-5): min(sz(3), zzmin+size(a1,3)+5)];    

        argn = uint16(a(yrange, xrange, zrange));    
        inimgrgn = uint16(inimg(yrange, xrange, zrange));                

        segrgn = uint16(f(yrange, xrange, zrange)); 
        segrgndilate = permute(imdilate(permute(imdilate(segrgn,se2), [1,3,2]), se2), [1,3,2]);        

        % estimate background level
        thre = graythresh(uint8(inimgrgn(segrgndilate==0)))*255;

        % get the mask
        rgnmask = uint16((inimgrgn .* uint16(segrgndilate==0)) > thre);
        rgnmask = uint16(imopen(rgnmask,se1));
        rgnmask = uint16(bwlabeln(rgnmask));

        jj = find(rgnmask .* argn >0);

        if (~isempty(jj))

            labeljj = unique(rgnmask(jj));

            stat = regionprops(rgnmask,'Area');
            [maxval, maxidx] = max([stat(labeljj).Area]);


            rgnmask = (rgnmask==labeljj(maxidx));

            rgnmask = gaussf(fillholes(rgnmask),1); 

            
            a(:) = 0;
            a(yrange, xrange, zrange) = rgnmask .* (segrgn==0);
            f(a>0) = max(f(:)) + 1;
        end; % if (~isempty(jj))
        
    end; % if 
    

end;

% ---------------------------
% assign value to segImg2new
% ---------------------------

segImg2new = f;

if (outlierRgnNum>1)
    foundflg = 1;
else
    foundflg = 0;
end;

return;