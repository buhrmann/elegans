function f = rgnMerge64(f, inimgrgn, holeimgrgn, rgnMaxSize)
% function f = rgnMerge64(f, inimgrgn, holeimgrgn, rgnMaxSize)
%
% merge regions
%
% Copyright F. Long
% Dec.5, 2006, revised from rgnMerge63.m

se1 = strel('disk', 1);

threMinSize = 4;
[rgnprop, f] = rgnStat63(inimgrgn, f, threMinSize); % compute region convexity

ss = regionprops(f, 'Area', 'PixelIdxList');

rgnnum = length(ss);
r = zeros(rgnnum);


% --------------------------
% calculate initial r matrix
% --------------------------

rgn_m = f;
rgn_mn = f;

for m=1:rgnnum
    
    rgn_m(:) = 0;
    rgn_m(ss(m).PixelIdxList) = 1; 

    
    if (ss(m).Area>0)

        rgn_m_d = permute(imdilate(permute(imdilate(rgn_m, se1), [1 3 2]), se1), [1 3 2]); 
        
        neighborRgnIdx = unique(rgn_m_d .* f); 
        neighborRgnIdx = setdiff(neighborRgnIdx, [0:m]); 
        
        for n =1:length(neighborRgnIdx)

            pl = [ss(m).PixelIdxList; ss(neighborRgnIdx(n)).PixelIdxList];
            rgn_mn(:) = 0;
            rgn_mn(pl) = 1;

            rgnCube = extractCube(uint8(rgn_mn), [ss(m).PixelIdxList; ss(neighborRgnIdx(n)).PixelIdxList]);
            r(m,neighborRgnIdx(n)) = convexRatio2(rgnCube);   
                        
        end;
    end;
end;
r = r + r';

%--------------------------------------------------------------------------------
% combine regions by iteratively modifying the convexity values in the r matrix
%--------------------------------------------------------------------------------

hval = 10;

a = imreconstruct(inimgrgn-hval,inimgrgn); 
a = inimgrgn-a;
localmax = bwlabeln(a.*uint16(f>0));

length(unique(localmax));
dip_image(localmax);

count = 1;
convex = [];
convex(1) = min(rgnprop(:,2));
fmatrix(:,:,:,1) = f;

while nnz(r)> 0    

    [val, idx2] = max(r(:));        
    [m,n] = ind2sub(size(r), idx2); 

    mergetag = 0; % 1 indicates the two regions need to be merged


    if ((ss(m).Area + ss(n).Area)<rgnMaxSize)

        mval = unique(localmax(ss(m).PixelIdxList));
        nval = unique(localmax(ss(n).PixelIdxList));        

        maxnum_m = length(mval)-1;
        maxnum_n = length(nval)-1;        

        if (maxnum_m==0)|(maxnum_n==0)
            mergetag = 1;
        end;

        if nnz(intersect(mval, nval))>0
            mergetag = 1;
        end;
       
        if (nnz(holeimgrgn(ss(m).PixelIdxList))>0) | (nnz(holeimgrgn(ss(n).PixelIdxList))>0)
            mergetag = 1;
        end;

        
        
    end;

    % merge operation
    if (mergetag == 0) % should not merge the two regions
        r(m,n) = 0;
        r(n,m) = 0;
    else

        % assign new label to the merged region
        f(ss(n).PixelIdxList) = m;  
        
        % update area and pixelIdxList
        ss(m).Area = ss(m).Area + ss(n).Area; % recompute region size
        ss(n).Area = 0;
        ss(m).PixelIdxList = [ss(m).PixelIdxList; ss(n).PixelIdxList];
        ss(n).PixelIdxList =[];        

        % recompute convexity of the merged region
        rgnprop(n,1) = 0; 
        rgnprop(n,2) = 999;
        
        rgnprop(m,1) = ss(m).Area;
        rgnprop(m,2) = val;
        
        count = count + 1;
        convex(count) = min(rgnprop(:,2));
        fmatrix(:,:,:,count) = f;
        
        % recompute the r(m,:)
        rgnadj = setdiff(union(find(r(m,:)>0), find(r(:,n)>0)), [m,n]); % find index of regions that are adjacent to region m and n
        r(:,n) = 0; % region_n does not exist any more, thus set the corresponding values to 0
        r(n,:) = 0;

        if (~isempty(rgnadj))

            rgn_m(:) = 0;
            rgn_m(ss(m).PixelIdxList) = 1; 
            rgn_m_d = permute(imdilate(permute(imdilate(rgn_m, se1), [1 3 2]), se1), [1 3 2]); 

            for n=1:length(rgnadj)

                pl = [ss(m).PixelIdxList; ss(rgnadj(n)).PixelIdxList];
                rgn_mn(:) = 0;
                rgn_mn(pl) = 1;


               rgnCube = extractCube(uint8(rgn_mn), [pl]);               
               r(m,rgnadj(n)) = convexRatio2(rgnCube);  
               
                r(rgnadj(n),m) = r(m,rgnadj(n));

            end;                    
        end;
        
        
        

     end; % if (mergetag == 0) end


end; % while end    

[maxval, maxidx] = max(convex);
idx = find(convex == maxval);

f = fmatrix(:,:,:,idx(end));

