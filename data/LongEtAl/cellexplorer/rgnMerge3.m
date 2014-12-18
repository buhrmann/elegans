function f = rgnMerge3(f, inimgrgn, rgnMinSize, rgnConvexityLow, threRatio)
% function f = rgnMerge3(f, inimgrgn, rgnMinSize, rgnConvexityLow, threRatio)
% 
% merge over-segmented regions
% Copyright F. Long
% Aug. 11, 2006


se1 = strel('disk', 1);


rgnnum = max(f(:));
r = zeros(rgnnum);

ss = regionprops(f, 'Area', 'PixelIdxList');
nb = find([ss.Area]<4);


for m=1:length(nb)
    f(ss(m).PixelIdxList) = 0; 
    ss(m).Area = 0;
    ss(m).PixelIdxList = [];
end;


rgn_m = f;
rgn_mn = f;

for m=1:rgnnum

%     [m, rgnnum] 
    
    
    rgn_m(:) = 0;
    rgn_m(ss(m).PixelIdxList) = 1; 

    if (ss(m).Area>0)

        rgn_m_d = permute(imdilate(permute(imdilate(rgn_m, se1), [1 3 2]), se1), [1 3 2]); 
        
        neighborRgnIdx = unique(rgn_m_d .* f); 
        neighborRgnIdx = setdiff(neighborRgnIdx, [0:m]); 
        [m, length(neighborRgnIdx)];
        
        for n =1:length(neighborRgnIdx)

            rgn_mn(:) = 0;
            rgn_mn([ss(m).PixelIdxList; ss(neighborRgnIdx(n)).PixelIdxList]) = 1;

            rgnCube = extractCube(uint8(rgn_mn), [ss(m).PixelIdxList; ss(neighborRgnIdx(n)).PixelIdxList]);
            r(m,neighborRgnIdx(n)) = convexRatio2(rgnCube);                    
        end;
    end;
end;

% merge
r = r + r';
stopmergetag = 0;        

while stopmergetag == 0    

    [val, idx2] = max(r(:));        
    [m,n] = ind2sub(size(r), idx2); 

    mergetag = 0; % 1 indicates the two regions need to be merged

    if (val>rgnConvexityLow) 
        
            pnn = sort(inimgrgn(ss(m).PixelIdxList),'descend'); 
            max_m = median(pnn(1:min(5,length(pnn)))); 

            pnn = sort(inimgrgn(ss(n).PixelIdxList),'descend'); 
            if (isempty(pnn))
                keyboard
            end;
            max_n = median(pnn(1:min(5,length(pnn)))); 

            maxval = max(max_m, max_n);

            pnn = f;
            pnn(:) = 0;
            pnn([ss(m).PixelIdxList; ss(n).PixelIdxList]) = (inimgrgn([ss(m).PixelIdxList; ss(n).PixelIdxList]) > maxval*threRatio); %20060808
            pnn = bwlabeln(pnn);

            hh = f;
            hh(:) = 0;

            hh(ss(m).PixelIdxList) = 1;
            hh(ss(n).PixelIdxList) = 2;


            num = max(pnn(:));
            if (num>1)
                v = 1;
                while (v<=num)&(mergetag ==0)
                    qq = hh(find(pnn==v));
                    if (length(unique(qq))>=2)
                        mergetag = 1; 
                    else
                        v = v+1;
                    end;

                end;

            else 
                mergetag = 1;
            end;
    else
        stopmergetag = 1;
    end; %if (val>rgnConvexityLow)  end
    

    if (mergetag == 0) 
        r(m,n) = 0;
        r(n,m) = 0;
    else

        f(ss(n).PixelIdxList) = m;  
        ss = regionprops(f, 'Area', 'PixelIdxList'); 


        rgnadj = setdiff(union(find(r(m,:)>0), find(r(:,n)>0)), [m,n]); 
        r(:,n) = 0; 
        r(n,:) = 0;
        

        if (~isempty(rgnadj))

            rgn_m(:) = 0;
            rgn_m(ss(m).PixelIdxList) = 1; 
            rgn_m_d = permute(imdilate(permute(imdilate(rgn_m, se1), [1 3 2]), se1), [1 3 2]); % matlab bug

            for n=1:length(rgnadj)

                rgn_mn(:) = 0;
                rgn_mn([ss(m).PixelIdxList; ss(rgnadj(n)).PixelIdxList]) = 1; 
                

               rgnCube = extractCube(uint8(rgn_mn), [ss(m).PixelIdxList; ss(rgnadj(n)).PixelIdxList]);               
               r(m,rgnadj(n)) = convexRatio2(rgnCube);                    
               r(rgnadj(n),m) = r(m,rgnadj(n));

            end;                    
        end;

    end; % if (mergetag == 0) end


end; % while end    