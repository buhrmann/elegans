function segImg2 = rgndilate62(segImg, inimg, maskImg,threConvexity,backgndLevel,method)
% function segImg2 = rgndilate62(segImg, inimg, maskImg,threConvexity,backgndLevel,method)

% dilate regions whose boundaries are smaller than their real sizes
%
% method: 0 --- morphological dilation
%         1 --- intensity dilation
% Copyright Fuhui Long
% 20061026

rstart =1;
rend = 8;
rstep = 1;
dis_x = 6;
dis_y = 6;
dis_z = 4;
    
se = strel('disk',1);

stat = regionprops(segImg, 'Area', 'PixelIdxList');
sz = size(segImg);

segImg2 = segImg; 

rgnidx = find([stat.Area]>0);

for i=1:length(rgnidx)

    segImg2(stat(rgnidx(i)).PixelIdxList) = 0;

    %[i,length(rgnidx)]

    [aa1, xxmin, yymin, zzmin] = extractCube_FL2(segImg, stat(rgnidx(i)).PixelIdxList); 

    yrange = [max(1, yymin-dis_y): min(sz(1), yymin+size(aa1,1)-1+dis_y)];
    xrange = [max(1, xxmin-dis_x): min(sz(2), xxmin+size(aa1,2)-1+dis_x)];
    zrange = [max(1, zzmin-dis_z): min(sz(3), zzmin+size(aa1,3)-1+dis_z)];   

    argn = uint16(segImg(yrange, xrange, zrange));  
    maskrgn = uint8(maskImg(yrange, xrange, zrange));
    inimgrgn = uint8(inimg(yrange, xrange, zrange)); 

    bb = argn;
    cc0 = ones(size(argn))*9999;
    dd = argn;
    dd(:) = 0;

    iidx = unique(argn(argn>0));
    num = length(iidx);

    for j = 1:num

        bb(:) = 0;
        bb(argn == iidx(j)) = 1;
        cc = bwdist(bb);
        cc0 = min(cc, cc0);
        val = uint8(cc<=cc0) .* uint8(cc0<rend);
        dd(val==1) = iidx(j);
    end;           



    count = 0;
    ee = uint8(dd==rgnidx(i)) .* maskrgn;

    % ----------------------------
    
    if (strcmp(method,'morp')) % method 1: morphological dilation
        
        meanval = mean(inimg(segImg==rgnidx(i)));
        ra = [];
        num = 0;
        ffold = ee;
        ffold(:)=0;

        wid_r = rstart;
        count = 0;
        ra = [];
        
        for j=rstart:rstep:rend

            count = count + 1;
            ff = uint8(cc0<j) .* ee;

            if (nnz(ff-ffold)>0)

                [y1,x1,z1] = ind2sub(size(ff), find(ff>0));
                pt = [y1,x1,z1];

                if (size(pt,1)>40)&(length(unique(z1))>1) 

                    [K,V] = convhulln(pt);
                    ra(count) = nnz(ff)/V;                    
                    if (ra(count)<threConvexity)    
                        break;
                    end;

                    ff1 = ff-ffold;

                    ind = find(ff1>0);
                    if (length(ind)>0)
                        if (mean(inimgrgn(ind))<backgndLevel)

                            break;
                        end;
                    end;

                end; 

                wid_r = j;
                ffold = ff; 

            end; 

        end; 

        ff = uint8(cc0<wid_r) .* ee;
    end;

    % ---------------------
    
    if (strcmp(method,'inte')) % method 2, intensity dilation

        thmax = min(min(min(inimgrgn(argn==rgnidx(i)))));
        th = min(min(min(inimgrgn(maskrgn>0))));

        pn = [];
        conv = [];
        bbmatrix = [];
        count = 0;

       
        while (1)
            [th, thmax];
            bb = imopen((inimgrgn .*ee>th),se);
            bb = uint16(bwlabeln(bb));
            
            cc = bb .* uint16(argn==rgnidx(i));
            ss = regionprops(cc,'Area');
            [maxval, maxidx] = max([ss.Area]);

            count = count + 1;
            rgnCube = uint16(bb==maxidx);
            bbmatrix(:,:,:,count) = rgnCube;

            [y1,x1,z1] = ind2sub(size(rgnCube), find(rgnCube>0));
            pt = [y1,x1,z1];
            [K,V] = convhulln(pt);
            conv(count) = nnz(rgnCube)/V;                    
    
            if (conv(count)>1.0) | (th>thmax)
                break;
            end;

            th = th + 5;
        end;

        if (th>thmax) & (length(conv)>=2)
            dconv = abs(conv(2:end)-conv(1:end-1));
            [maxval, maxidx] = max(dconv);
            [maxidx, length(conv)];
             rgnCube = squeeze(bbmatrix(:,:,:,maxidx+1));        
        end;

        ff = rgnCube;
    end;

    % --------------------
    
    ind = find(ff>0);
    [yy,xx,zz] = ind2sub(size(argn), ind);

    yy = yy+yymin-dis_y-1;
    xx = xx+xxmin-dis_x-1;            
    zz = zz+zzmin-dis_z-1;
    
    if (min(yy)<=0)
        yy = yy-yymin+dis_y+1;
    end;
    
    if (min(xx)<=0)
        xx = xx-xxmin+dis_x+1;
    end;

    if (min(zz)<=0)
        zz = zz-zzmin+dis_z+1;
    end;

    ind = sub2ind(sz, yy,xx,zz);

    segImg2(ind) = rgnidx(i);
        
end; 

return;
