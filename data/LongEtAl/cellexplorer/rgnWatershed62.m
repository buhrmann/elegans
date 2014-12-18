function [f,thre] = rgnWatershed62(argn, inimgrgn, thre0, imgproptag, method)
% function [f,thre] = rgnWatershed62(argn, inimgrgn, thre0, imgproptag, method)
%
% region segmentation using watershed segmentation
% Copyright F. Long
% latest update 20061230

if (method<4 | method>6)
    return;
end;


% ---------  method 4. pure shape based watershed using higher threshold---------------

if (method ==4)
    if (imgproptag == 0) 
        tmp = uint8(inimgrgn);
         thre = graythresh(tmp(find(argn>0)))*255; 
    else
        thre = thre0 + 3;
    end;

    b = uint16(inimgrgn>thre) .* argn;
    b = fillholes(b);


    stp = 0;
    b_old = argn;

    while stp ==0 

        if (abs(nnz(b_old)-nnz(b))>10)    
            stp = 1;

        else
            thre = thre + 3;
            b_old = b;
        end;

        b = uint16(inimgrgn>thre) .* argn;
        b = fillholes(b);

        if (nnz(b)==0)
            stp = 1;
        end;


    end;  

    c = bwdist(b==0);
    c = max(c(:))-c;
    c(c==max(c(:))) = -Inf; 

end;


% % ---------  method 5. pure shape based watershed without increasing threshold---------------
if (method ==5)
    c = bwdist(argn==0);
    c = max(c(:))-c;
    c(argn==0) = -Inf;
    thre = thre0;
end;


% % -----  method 6: image reconstruction and shape based watershed   -----------

if (method==6) 
    c = double(varif(inimgrgn, 2, 'elliptic'));

    hval = max(inimgrgn(argn>0))-graythresh(uint8(inimgrgn(argn>0)))*255;
    a = imreconstruct(inimgrgn-hval,inimgrgn); 
    a = inimgrgn-a;
     a = bwlabeln((a.*argn)>0);

    c = bwdist(a==0);
    c = max(c(:))-c;

    c(c==max(c(:))) = -Inf;

    thre = thre0;
end;


%f = uint16(watershed(c)); %work for me
f = uint16(watershed_old(c)); % work for xiao

% remove watershed line 

stat = regionprops(f,'PixelIdxList');

f1 = f;
cc0 = uint16(ones(size(argn))*9999);
dd = argn;
dd(:) = 0;

kkend = max(f(:));

sz = size(f);

for kk=2:kkend 
    kk;
    f1(:) = 0;
    f1(stat(kk).PixelIdxList) = 1;
    
    [f2, xxmin, yymin, zzmin] = extractCube_FL2(f1, stat(kk).PixelIdxList);    %20060808
    
    yrange = [max(1, yymin-10): min(sz(1), yymin+size(f2,1)+10)];
    xrange = [max(1, xxmin-10): min(sz(2), xxmin+size(f2,2)+10)];
    zrange = [max(1, zzmin-3): min(sz(3), zzmin+size(f2,3)+3)]; 

    f2 = f1(yrange, xrange, zrange);
    
    f3 = bwdist(f2);

    cc = uint16(ones(size(argn))*9999);
    cc(yrange, xrange, zrange) = f3;
    
    cc0 = min(cc, cc0);

    val = (cc<=cc0);
    dd(val==1) = kk;
end;


f = f.*uint16(f>1)+dd.*uint16(f==0);
f(f>0) = f(f>0)-1; 
dip_image(f);