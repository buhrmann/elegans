function segNucleiGFP(inimgname1, inimgname2, outimgname, cellnumber, filltag) 
% function segNucleiGFP(inimgname1, inimgname2, outimgname, cellnumber, filltag) 
%
% Segmente nuclei in GFP channel
%
% F. Long

% --------------------------
% initialize parameters
% --------------------------
rgnMinSize = 200;
rgnConvexityLow = 0.85; 
threRatio = 0.5; 

% -----------
% load image
% -----------

img = uint8(readim(inimgname1)); % read GFP image
img = permute(img, [2 1 3 4]);
inimg = img;

img = uint8(readim(inimgname2)); % read DAPI image
img = permute(img, [2 1 3 4]);
refimg = img;

clear img;

dapithre = graythresh(refimg)*255; 

% -----------
% filling holes
% -----------
if filltag==1

    threlowest = min(10, graythresh(inimg)*255); 

    fprintf('Filling holes ...\n');
    inimg= fillNucleiHolesInStack(inimg, threlowest,rgnMinSize);
end;


% ---------------------------------------------------------
% thresholding, take the result as an initial segmentation
% ---------------------------------------------------------

fprintf('Generating initial segmentation ...\n');
thre0 = graythresh(inimg)*255; 

maskImg = (inimg>thre0);

d= uint8(gaussf(maskImg,1)); 
e = uint16(bwlabeln(d));

clear d;

stat = regionprops(e,'Area','PixelIdxList');
rgn = [stat.Area];
mediansz = median(rgn);

idx2 = find(rgn>rgnMinSize); 

kknum = length(idx2);
tt = e;
e(:) = 0;

for kk=1:kknum

    tt(:) = 0;
    tt(stat(idx2(kk)).PixelIdxList) = 1;

    [argn, xxmin, yymin, zzmin] = extractCube_FL2(tt, stat(idx2(kk)).PixelIdxList);    
    argn = fillholes(argn); 

    tt([yymin: yymin+size(argn,1)-1], [xxmin: xxmin+size(argn,2)-1], [zzmin: zzmin+size(argn,3)-1]) = argn;
    e(tt>0) = kk;    

end;         

segImg2 = e; 

clear e;

% -----------------------------------------------------------------------
% detect regions that are 1) unlikely to be nuclei; 2) need splitting
% -----------------------------------------------------------------------

[rgnSeg,segImg2] = rgnStat8(inimg, segImg2, rgnMinSize, 1, 1); 

feaind = [1, 4, 12]; % size, major axis eign value, z dimension size
threfea = [0.2, 10, 0.25]; 

medval = median(rgnSeg(:,feaind));

discardRgn = [];
ss = regionprops(segImg2, 'PixelIdxList');

for i=1:length(ss)
    
    if nnz(refimg(ss(i).PixelIdxList)'>dapithre)/nnz(ss(i).PixelIdxList) < 0.02 % deal with donut
        discardRgn = [discardRgn, i];
    end;
end;
    
if ~isempty(discardRgn)
    
    fprintf('discard false regions ...\n');

    ss = regionprops(segImg2, 'PixelIdxList');

    for i=1:length(discardRgn)
        segImg2(ss(discardRgn(i)).PixelIdxList)  = 0;
    end;
end;


feaind = [1,4]; 
threfea = [2,2];

medval = median(rgnSeg(:,feaind));
splitRgn = [1:size(rgnSeg,1)];

for i=1:length(feaind)
    splitRgn = intersect(splitRgn, find(rgnSeg(:, feaind(i))>threfea(i).*medval(i)));
end;

splitRgn = setdiff(splitRgn, discardRgn);


% ------------
% split regions
% ------------


if ~isempty(splitRgn)
    fprintf('Split regions ...\n');

    stat = regionprops(segImg2, 'PixelIdxList');

    splitRgnNum = length(splitRgn);

    for i=1:splitRgnNum

        thre = thre0;

        [rgnMask, xxmin, yymin, zzmin] = extractCube_FL2(segImg2, stat(splitRgn(i)).PixelIdxList);   
        sz = size(rgnMask);

        rgnInimg = inimg(yymin:yymin+sz(1)-1, xxmin:xxmin+sz(2)-1, zzmin:zzmin+sz(3)-1);

        tt = uint16(rgnMask>0);

        ww = uint16(watershedSeg3d2(tt, rgnInimg, 1, 0, rgnConvexityLow, threRatio));  

        if (length(unique(ww(ww>0)))>1) % more than one region

            [dist, lab] = bwdist(ww>0);
            ww2 = uint16(ww(lab)) .* uint16(rgnMask>0);

            segImg2(stat(splitRgn(i)).PixelIdxList) = 0;                
            segImg2(stat(splitRgn(i)).PixelIdxList) = max(segImg2(:)) + ww2(ww2>0);

        else %still one region
            
           ttold = rgnMask;
           terminateTag = 0;
           
           while terminateTag == 0
               
                % increase intensity level
                stp = 0;
                while stp ==0 

                    thre = thre + 5;
                    tt = uint16(rgnInimg>thre).*uint16(rgnMask); %20060912

                    if (nnz(tt)==0)
                        stp = 1;
                        terminateTag = 1;
                    end;

                    if (abs(nnz(tt)-nnz(ttold))>10) 
                        stp = 1;

                        tt= uint8(gaussf(tt,1)); 
                        tt = bwlabeln(tt);
                    else
                        ttold = tt;

                    end;
                end;                  


                if (nnz(tt)>0)

                    ww = uint16(watershedSeg3d2(tt, rgnInimg, [1:max(tt(:))], 0, rgnConvexityLow, threRatio));  % 20060912

                    if (length(unique(ww(ww>0)))>1) % more than one region

                        % dilate
                        [dist, lab] = bwdist(ww>0);
                        ww2 = uint16(ww(lab)) .* uint16(rgnMask>0);

                        segImg2(stat(splitRgn(i)).PixelIdxList) = 0;                
                        segImg2(stat(splitRgn(i)).PixelIdxList) = max(segImg2(:)) + ww2(ww2>0);
                        terminateTag = 1;

                    else % still one region, use original label

                        segImg2(stat(splitRgn(i)).PixelIdxList) = 0;                
                        segImg2(stat(splitRgn(i)).PixelIdxList) = max(segImg2(:)) + 1;
                        
                     end;

                end;
           end;

        end; % if (length(unique(ww(ww>0)))>1) end

    end; % for end
end;
    
 
% ------------------------------------------------------------------
% recover potential missing cells when the number is less than 82
% (due to weak staining and global thresholding)
% ------------------------------------------------------------------

segnum = length(unique(segImg2(segImg2>0)));
feaind = [1:6,10:12]; % refer to rgnStat8 for the meaning of these features

if (segnum < cellnumber) 
    
    fprintf('Recovering missing regions ...\n');

    inimgdome = inimg - imreconstruct(inimg - min(10, thre0), inimg);
    inimgdome = uint8(gaussf(inimgdome,1));

    f = uint16(bwlabeln(inimgdome>0));
    
    clear inimgdome;

    stat = regionprops(f,'Area', 'PixelIdxList');

    % remove regions that are too big or too small

    idx2 = find(([stat.Area]>5*mediansz)|([stat.Area]<rgnMinSize));

    num = length(idx2);

    for i=1:num
        f(stat(idx2(i)).PixelIdxList) = 0;
    end;

    % detect the local maxima that are missed in the initial segmentatation

    f1 = uint16(segImg2>0).*uint16(f);
    idx2 = unique(f1(f1>0));
    num = length(idx2);

    clear f1;
    

    for i=1:num
        f(stat(idx2(i)).PixelIdxList) = 0;
    end;

    stat = regionprops(f, 'Area', 'PixelIdxList');
    clear f;
    
    idx2 = find([stat.Area]>0);
    num = length(idx2);
    curlabel = 0;
    recoverImg = segImg2;
    recoverImg(:) = 0;
    
    for i=1:num
        curlabel = curlabel + 1;
        recoverImg(stat(idx2(i)).PixelIdxList) = curlabel;
    end;
        
    ss = regionprops(recoverImg, 'PixelIdxList');
    
    discardRgn2 = [];
    
    for i=1:length(ss)
        if nnz(refimg(ss(i).PixelIdxList)'>dapithre)/nnz(ss(i).PixelIdxList) < 0.02 
            discardRgn2 = [discardRgn2, i];
        end;
    end;

    for i=1:length(discardRgn2)
        recoverImg(ss(discardRgn2(i)).PixelIdxList)  = 0;
    end;

    [recrgnSeg,recoverImg] = rgnStat8(inimg, recoverImg, rgnMinSize, 1, 1); 
    ss = regionprops(recoverImg, 'PixelIdxList');

    if cellnumber~=999 
        
        for i=1:length(ss)
            recrgnSeg(i,14) = 255-max(inimg(ss(i).PixelIdxList)); % intensity, the less recrgnSeg(i,14), the more likely it is a missing nuclei
        end;

        iii = setdiff([1:length(rgnSeg)],[splitRgn, discardRgn]); % iii are potential right nuclei regions

        nn = median(rgnSeg(iii,feaind));
        tmp = abs(recrgnSeg(:,[feaind,14]) - repmat([nn,0],[size(recrgnSeg,1) 1]));

        [sortval, sortidx] = sort(tmp);

        % method 2
        tmp2 = cumsum(sortval,1);
        maxval = max(tmp2, [],1);
        minval = min(tmp2, [],1);

        stepval = (maxval-minval)/size(sortval,1);

        len1  = size(sortval,1);
        len2 = size(sortval,2);
        p = [];

        for i=1:len2
            tmp3 = repmat(tmp2(:,i), [1 len1]) - repmat([minval(i):stepval(i):minval(i)+(len1-1)*stepval(i)], [size(sortval,1),1]);
            for j=1:len1
                p(sortidx(j,i),i) = nnz(tmp3(j,:)>=0);

            end;
        end;

        [val, iii] = sort(mean(p,2));
        recoverRgn = iii(1:min(cellnumber - segnum, length(iii)));
        discardRgn2 = setdiff([1:len1], recoverRgn);

        for i=1:length(discardRgn2)
            recoverImg(ss(discardRgn2(i)).PixelIdxList)  = 0;
        end;
        
    else 
        
        feaind = [1,4]; % size, major axis eign value
        threfea = [2,2];

        medval = median(rgnSeg(:,feaind));
        splitRgn = [1:size(recrgnSeg,1)];

        for i=1:length(feaind)
            splitRgn = intersect(splitRgn, find(recrgnSeg(:, feaind(i))>threfea(i).*medval(i)));
        end;

        splitRgn = union(splitRgn, find(recrgnSeg(:,2)<0.9)); 
     
        
        ww = uint16(watershedSeg3d2(recoverImg, inimg, splitRgn, 0, rgnConvexityLow, threRatio));  % 20060912

        for i=1:length(splitRgn)
            recoverImg(ss(splitRgn(i)).PixelIdxList) = 0;
        end;
        recoverImg = recoverImg + (max(recoverImg(:)) + ww).*uint16(ww>0);
    end;

    segImg2 = segImg2 + (max(segImg2(:)) + recoverImg).*uint16(recoverImg>0);
    
end;


% ------------------------------------------------------
% make label continuous, sort regions along AP axis
% ------------------------------------------------------

[rgnSeg,segImg2] = rgnStat3(inimg, uint16(segImg2), 0,1,0);  
rgn = regionprops(segImg2,'PixelIdxList');
r = struct(measure(segImg2, inimg, {'gravity'}));

 
rgnnum = length(rgnSeg);
ss = [];
for i=1:rgnnum
   ss(i) = r(i).Gravity(1);
end;

[ssnew, ssidx] = sort(ss,'ascend');


segres = uint16(segImg2);
segres(:) = 0;


for i=1:rgnnum % regions with size NaN is sorted to the end  
    segres(rgn(ssidx(i)).PixelIdxList) = i;
end;
    
%--------------------------------
% permute, to make X bigger than Y
% 20090226 fix bug
%--------------------------------    

if (size(segres,1) > size(segres,2))
    segres = permute(segres, [2 1 3]);
end;

%----------------------
% save file
%----------------------

save(outimgname,'segres');

close all;

