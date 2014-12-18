function outimg = fillNucleiHolesInStack(inimg, threlowest,rgnMinSize)
% function outimg = fillNucleiHolesInStack(inimg, threlowest,rgnMinSize)
%
% fill holes in nuclei to get a good mask for segmentation
% Copyright F.Long
% Dec.15, 2006

nnalld = [];

threInitial = threlowest;
se1 = strel('disk',1);    
se2 = strel('disk',2);    

d = inimg>threInitial;
d = uint8(gaussf(d,1)); 
e = uint16(bwlabeln(d));

stat = regionprops(e,'Area', 'PixelIdxList');
rgn = [stat.Area];

% ignore small regions
idx2 = find(rgn>rgnMinSize);

kknum = length(idx2);
tt = e;

sz = size(inimg);
threstep = 2;

outimg = inimg;

for kk=1:kknum
    
    tt(:) = 0;
    tt(stat(idx2(kk)).PixelIdxList) = 1;
    [argn, xxmin, yymin, zzmin] = extractCube_FL2(tt, stat(idx2(kk)).PixelIdxList);
    
    yrange = [max(1, yymin+1-2): min(sz(1), yymin+size(argn,1)+2)];
    xrange = [max(1, xxmin+1-2): min(sz(2), xxmin+size(argn,2)+2)];
    zrange = [max(1, zzmin+1-2): min(sz(3), zzmin+size(argn,3)+2)];    

    argn = uint8(tt(yrange, xrange, zrange));    
    inimgrgn = uint8(inimg(yrange, xrange, zrange));        

    maxthre = max(inimgrgn(argn>0));
    nnall = argn;
    nnall(:) = 0;
    
    d0 =  uint8(inimgrgn>threInitial) .*argn;
    d0 = fillholes(d0);
    dist0 = bwdist(~d0);
    mask0 = uint8(dist0>3);
    
    thre = threInitial;
    
    while thre<maxthre

        d = uint8(inimgrgn>thre) .*argn;

        d1 = fillholes(d); 

        nn = uint8(d1)-uint8(d);

        nn = nn .* mask0; 
        
        nn2 = bwlabeln(nn);
        ss = regionprops(nn2,'Area', 'PixelIdxList');
        iii = find([ss.Area]<10); 
        
        for j = 1:length(iii)
            nn(ss(iii(j)).PixelIdxList) = 0;
        end;
        
        if nnz(nn)>0
            nnall = uint8((nn + nnall)>0);
        else % accelerate
            if (thre-threInitial)/threstep>10 
                break;
            end;
        end;
        thre = thre+threstep;
    end;

    if (nnz(nnall)>0)

        nnalld = (permute(imdilate(permute(imdilate(nnall, se1), [1 3 2]), se1), [1 3 2]));
        nnalld2 = (permute(imdilate(permute(imdilate(nnall, se2), [1 3 2]), se2), [1 3 2]));

        tmp = nnalld2-nnalld;

        baseinte = median(inimgrgn(tmp>0));

        maxval2 = max(inimgrgn(nnalld>0));    

        inimgrgn2 = inimgrgn;
        inimgrgn2(:) = 0;
        
        inimgrgn2(nnalld>0) = baseinte;

        tt(:) = 0;
        tt(yrange,xrange, zrange) = inimgrgn2;
        outimg(tt>0) = tt(tt>0);
    end;
    
end;               


