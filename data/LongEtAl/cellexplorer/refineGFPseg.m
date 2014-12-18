function segres = refineGFPseg(manualSegImg, autoSegImg, inimgGFP, inimgDAPI)
% function segres = refineGFPseg(manualSegImg, autoSegImg, inimgGFP, inimgDAPI)
% 
% refine GFP segmenation mask based on manual correction
% F. Long
% 20080818
    
% check each region in manual correction result
label = unique(manualSegImg(manualSegImg>0));
rgnnum = length(label);

ss = regionprops(manualSegImg, 'PixelIdxList');
a = autoSegImg;
sz = size(autoSegImg);

corautoSegImg = manualSegImg;

% correct each region
for j = 1:rgnnum

   if nnz(autoSegImg(ss(label(j)).PixelIdxList) ~= manualSegImg(ss(label(j)).PixelIdxList))>0 % region has been changed
       label(j)

        % crop manual corrected segmentation image
        a(:) = 0;
        a(ss(label(j)).PixelIdxList) = manualSegImg(ss(label(j)).PixelIdxList(1));

        [a1, xxmin, yymin, zzmin] = extractCube_FL2(a, ss(label(j)).PixelIdxList);

        yrange = [max(1, yymin+1-5): min(sz(1), yymin+size(a1,1)+5)];
        xrange = [max(1, xxmin+1-5): min(sz(2), xxmin+size(a1,2)+5)];
        zrange = [max(1, zzmin+1-2): min(sz(3), zzmin+size(a1,3)+2)];    


        mrgn = uint16(a(yrange, xrange, zrange));    

        % crop auto segmentation image

        argn = uint16(autoSegImg(yrange, xrange, zrange));    
        inimgGFPrgn = uint8(inimgGFP(yrange, xrange, zrange));    
        inimgDAPIrgn = uint8(inimgDAPI(yrange, xrange, zrange));    

        % display
        fprintf('GFP intensity profile ');
        dip_image(inimgGFPrgn)
        fprintf('DAPI intensity profile ');        
        dip_image(inimgDAPIrgn)
        fprintf('Manual segmentation mask ');        
        dip_image(mrgn)
        fprintf('Automated segmentation mask ');        
        dip_image(argn)

        % deal with different cases
        alabel = unique(autoSegImg(ss(label(j)).PixelIdxList));

        if (nnz(alabel>0)==length(alabel))&(length(alabel)>1) % merge
            fprintf('Cells already merged, do nothing\n');
        else

            alabel = setdiff(alabel,0);

            tag = 1;

            if length(alabel) ==1

                r = nnz(uint8(autoSegImg==alabel))/(nnz(uint8(manualSegImg==label(j)).*uint8(autoSegImg==alabel)));
                if r<1.5 % resize
                    fprintf('Resize cells \n');
                else % split
                    fprintf('Split cells\n');
                    tag = 0;
                end;
            end;

            if isempty(alabel) % missing
                fprintf('Recover cells\n');
            end;

            % thresholding

            hh = regionprops(uint8(mrgn>0),'Centroid');

            thre = graythresh(uint8(inimgGFPrgn))*255;


            while (1)

                thre = min(thre, inimgGFPrgn(round(hh(1).Centroid(2)),round(hh(1).Centroid(1)),round(hh(1).Centroid(3))));

                segImgrgn = uint8(gaussf((inimgGFPrgn)>thre,1));
                segImgrgn = uint16(bwlabeln(segImgrgn));

                [rgnSeg,segImgrgn] = rgnStat3(inimgGFPrgn, uint16(segImgrgn),100,1,0); 
                rgnSeg(:,2)

                fprintf('Newly thresholded mask (before segmentation) ');                 
                dip_image(segImgrgn)

                tt = input('Apply watershed? (y/n)','s');

                if (strcmp(tt, 'y') ==1)

                    threImg = segImgrgn; threImg(:) = thre;
                    [segImgrgn, threImg] = watershedSeg3d62(segImgrgn, inimgGFPrgn, [1:max(segImgrgn(:))], 100, 0.9, threImg, 1, 5,5000);

                    fprintf('New watershed segmentation result ');                 
                    
                    dip_image(segImgrgn)

                    rgnidx = input('Which regions should be included (e.g., [1 2 3]) ');

                    ssrgn = regionprops(segImgrgn, 'PixelIdxList');
                    segImgrgn(:) = 0;

                    for m=1:length(rgnidx)
                        segImgrgn(ssrgn(rgnidx(m)).PixelIdxList) = 1;
                    end;
                    
                    fprintf('New segmentation result according to selected regions ');                                  
                    dip_image(segImgrgn)

                else

                    if max(segImgrgn(:))>1 % remove small debris

                        ssrgn = regionprops(segImgrgn, 'PixelIdxList');
                        iii = segImgrgn(round(hh(1).Centroid(2)),round(hh(1).Centroid(1)),round(hh(1).Centroid(3)));

                        iii = setdiff([1:max(segImgrgn(:))], iii);

                        for m=1:length(iii)
                            segImgrgn(ssrgn(iii(m)).PixelIdxList) = 0;
                        end;
                    end;
                    
                    fprintf('New segmentation result ');                                  
                   
                    dip_image(segImgrgn)

                end;



                ps = input('Should this new mask be: 1) acceptable, 2) bigger, 3) smaller, 4)replaced with manual mask ? (enter 1,2,3,or 4, any other key means acceptable) ','s');

                switch ps
                    case '2'
                        thre = thre - 5;
                    case '3'
                        thre = thre + 5;
                    case '4' % do nothing
                          break;
                    otherwise % '1' or any other keyes mean acceptable 

                        corautoSegImg(ss(label(j)).PixelIdxList) = 0;
                        a(:) = 0;
                        a(yrange, xrange, zrange) = segImgrgn;

                        corautoSegImg(a>0) = max(corautoSegImg(:)) + a(a>0);
                        break;

                end;
            end;% while end
        end; 

        fprintf('Press a key to continue\n');
        pause;
        close all;

   end;
end;% for j = 1:rgnnum

% make labels continous, remove debris generated by manual correction,

ss2 = regionprops(corautoSegImg, 'PixelIdxList', 'Area');

iii = find([ss2.Area]>0);
rgnnum = length(iii);

segres = corautoSegImg;
segres(:) = 0;

for m=1:rgnnum

   a(:) = 0;
   a(ss2(iii(m)).PixelIdxList) = 1;


   [a1, xxmin, yymin, zzmin] = extractCube_FL2(a, ss2(iii(m)).PixelIdxList);

   a1 = bwlabeln(a1);

   if (max(a1(:))>1)

       m
       ss3 = regionprops(a1, 'Area', 'PixelIdxList');
       [ss3.Area]
       [maxval, maxidx] = max([ss3.Area]);
       jjj = setdiff([1:max(a1(:))], maxidx);

        for n=1:length(jjj)
            a1(ss3(jjj(n)).PixelIdxList) = 0;
        end;

        a(:) = 0;
        a(yymin:yymin+size(a1,1)-1, xxmin:xxmin+size(a1,2)-1, zzmin:zzmin+size(a1,3)-1) = a1;
        segres(a>0) = m;
   else
       segres(ss2(iii(m)).PixelIdxList) = m;
   end;
end;

% sort along AP
rgn = regionprops(segres,'PixelIdxList');
r = struct(measure(uint16(segres), uint16(inimgGFP), {'gravity'}));

rgnnum = length(rgn);
ss = [];
for m=1:rgnnum
   ss(m) = r(m).Gravity(1);
end;

[ssnew, ssidx] = sort(ss,'ascend');


segres = uint16(segres);
segres(:) = 0;

for m=1:rgnnum % regions with size NaN is sorted to the end  
    segres(rgn(ssidx(m)).PixelIdxList) = m;
end;

