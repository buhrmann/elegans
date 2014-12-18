function [segImg2new, foundflg] = rgnSplit(inimg, segImg2, rgnSeg, szratio)
% function [segImg2new, foundflg] = rgnSplit(inimg, segImg2, rgnSeg, szratio)
% 
% split big regions using h-dome
%
%
% copyright Fuhui Long
% Aug 13, 2008

segImg2new = segImg2;

se1 = strel('disk',1);
se2 = strel('disk',2);

% --------------------------
% get statistics of regions
% --------------------------

mediansz = median(rgnSeg(:,1));
stat2 = regionprops(segImg2, 'PixelIdxList');

% ------------------------
% find big regions
% ------------------------

szidx = find(rgnSeg(:,1)>szratio*mediansz); 
cvidx = find(rgnSeg(:,2)<1.1); 

outlierIdx = intersect(cvidx, szidx);

outlierRgnMask = segImg2new;
outlierRgnMask(:) = 0;

outlierRgnNum = length(outlierIdx);

for i=1:outlierRgnNum
    outlierRgnMask(stat2(outlierIdx(i)).PixelIdxList) = outlierIdx(i);
    
end;

dip_image(outlierRgnMask);

% --------------------------------- 
% further segment outlier regions
% ---------------------------------
   
outlierRgnMaskSeg = outlierRgnMask;

tt = outlierRgnMask;

sz = size(inimg);

tt2 = segImg2;
holesz = [];
threstep = 5;

if (outlierRgnNum>1)
   
    foundflg = 1;
   
     for i=1:outlierRgnNum

    
        tt(:) = 0;
        tt(stat2(outlierIdx(i)).PixelIdxList) = 1;    

        [a1, xxmin, yymin, zzmin] = extractCube_FL2(tt, stat2(outlierIdx(i)).PixelIdxList);

        yrange = [max(1, yymin+1-2): min(sz(1), yymin+size(a1,1)+2)];
        xrange = [max(1, xxmin+1-2): min(sz(2), xxmin+size(a1,2)+2)];
        zrange = [max(1, zzmin+1-2): min(sz(3), zzmin+size(a1,3)+2)];    

        argn = uint8(tt(yrange, xrange, zrange));    
        inimgrgn = uint8(inimg(yrange, xrange, zrange));    
        
        thre = min(inimgrgn(argn>0))+threstep;
        maxthre = max(inimgrgn(argn>0));
        nnall = argn;
        nnall(:) = 0;

        
        while thre<maxthre

            d = uint8(inimgrgn>thre) .*argn;

            % fill holes 
            d1 = fillholes(d); 
            nn = uint8(d1)-uint8(d);

            if nnz(nn)>0
                nnall = uint8((nn + nnall)>0);
            end;
            thre = thre+threstep;
           
        end;
        holesz(i) = nnz(nnall);
        
        maxi = max(inimgrgn(argn>0));
        mini = min(inimgrgn(argn>0));

        rrr = [];
        rgnnum = [];

        rrr(1) = 0;
        rgnnum(1) = 999;
        vv = 1;

        bmatrix = [];
        
        while rrr(vv)<1.5
            vv = vv + 1;

            rrr(vv) = rrr(vv-1)+0.01;

             hval = maxi*rrr(vv);
            a = imreconstruct(inimgrgn-hval,inimgrgn); 
            a = (inimgrgn-a) .* uint8(argn);
            b = bwlabeln(a>0);
            rgnnum(vv)= max(b(:));
            
            %if (prod(size(b))>64*64*64), %skip too big region
            %    continue;
            %else,
            try,
				bmatrix(:,:,:,vv) = b;
			catch,
                continue;
            end;

            %end;
        end;
        
        rgnnum = rgnnum .* double(rgnnum<6);
        [maxval, maxidx] = max(rgnnum);
        
        b = bmatrix(:,:,:,maxidx);
        
        kk = find(rgnnum==1);
        rgnnum = rgnnum(maxidx); 
        
        if (~isempty(kk)) 
            if (rrr(kk(1))<1) & (holesz(i)<50) 


                if (rgnnum>1)

                    bb = a;
                    dd = a;
                    dd(:) = 0;
                    cc0 = ones(size(a))*9999;

                    for j = 1:rgnnum

                        bb(:) = 0;
                        bb(b == j) = 1;
                        cc = bwdist(bb);
                        cc0 = min(cc, cc0);
                        val = uint8(cc<=cc0);
                        dd(val==1) = j;
                    end;           

                    f = dd.* uint8(argn>0);

                    [rgnprop, f] = rgnStat63(inimgrgn, f, 4); % compute region convexity
                    ss = regionprops(f, 'Area', 'PixelIdxList');

                    measuresz = [];
                    measuresz(1) = min(rgnprop(:,1));

                    fmatrix = [];
                    fmatrix(:,:,:,1) = f;        

                    count = 1;

                    % compute convexity matrix r

                    r = zeros(length(ss)); 

                    rgn_m = f;
                    rgn_mn = f;

                     for m=1:length(ss)

                        if (ss(m).Area>0)
                            
                            rgn_m(:) = 0;
                            rgn_m(ss(m).PixelIdxList) = 1; 

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

                    % merge subregions

                    while nnz(r)> 0    

                        [val, idx2] = max(r(:));        
                        [m,n] = ind2sub(size(r), idx2); 

                         mergetag = 1;

                        % merge operation
                        if (mergetag == 0) % should not merge the two regions
                            r(m,n) = 0;
                            r(n,m) = 0;
                        else

                            % assign new label to the merged region
                            f(ss(n).PixelIdxList) = m;  %20060808

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

                            hh = find(rgnprop(:,1)>0);

                            ll = find(rgnprop(:,1)>0);
                            measuresz(count) = min(rgnprop(ll,1));
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

                     rgnmaxnum = round(rgnSeg(outlierIdx(i),1)/mediansz);
                     jj = rgnnum-rgnmaxnum+1;

                     jj = min(max(jj,1),length(measuresz));

                     if (measuresz(jj)>mediansz/3) % otherwise, use original mask

                         f = fmatrix(:,:,:,jj);                     

                        % assign label
                        tt2(:) = 0;
                        tt2(yrange, xrange, zrange) = f;

                        segImg2new(tt>0) = 0;
                        segImg2new(tt2>0) = uint16(max(segImg2new(:))) + uint16(tt2(tt2>0));

                        outlierRgnMaskSeg(tt>0) = 0;
                        outlierRgnMaskSeg(tt2>0) = uint16(max(outlierRgnMaskSeg(:))) + uint16(tt2(tt2>0));                    



                     end;


                end; %        if (rgnnum>1)

            end; % if rrr(kk)<1
        end;% if (~isempty(kk))

    end; %  for i=1:outlierRgnNum
else
    foundflg = 0;
end; %if (outlierRgnNum>1) end

        
        
return;





    
