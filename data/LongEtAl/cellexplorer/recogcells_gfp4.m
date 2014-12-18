function pl = recogcells_gfp4(locPatTestFilename, locPatTrainingFilename, testFilenamePrefix1, testFilenamePrefix2, testGFPSegFilename, testStackIdx, trainingStackIdx, cellNameFile, outfilename, verifytag, id_gfp, id_dapi)
% function pl = recogcells_gfp4(locPatTestFilename, locPatTrainingFilename, testFilenamePrefix1, testFilenamePrefix2, testGFPSegFilename, testStackIdx, trainingStackIdx, cellNameFile, outfilename, verifytag, id_gfp, id_dapi)

% automatically recognize cells in GFP channel (muscle cells)
%
% copyright: F. Long
% 20080818


% --------------
% initialization
% --------------

% load cell location files in test and training stacks

test = load(locPatTestFilename); 
training = load(locPatTrainingFilename);

musclecell = [37:118]; 

% load cell name 
count = 0;
cellNameSet = [];
linelist = loadfilelist(cellNameFile);

for i=1:length(linelist)
    if (~isempty(linelist{i}))
        count = count + 1;
        cellNameSet{count}=linelist{i};

    end;
end;


nucleinum = length(cellNameSet);


stacknum1 = length(testStackIdx);
stacknum2 = length(trainingStackIdx);

maxval = 999;

itermno = 12;

load training_data/cellTypeIdx2.mat; % obtain 'order' matrix

for testStack = testStackIdx
    
    %------------------------------------------------------
    % get DVLR partition of the cross view projection
    %------------------------------------------------------
    
    fprintf('The current test stack index is %d\n', testStack);
    
    coefDVLR_filename = [testFilenamePrefix2{testStack}, '_coef_DVLR_new.mat'];

    if ~exist(coefDVLR_filename) % load file if exist

        filename = [testFilenamePrefix2{testStack},'_crop_straight.raw'];  

        b = loadRaw2Stack(filename);
        b = permute(b, [2 1 3 4]);   

        [DVLR, VRcenter, VLcenter, DRcenter, DLcenter] = computeDVLR2(b, id_dapi,id_gfp, filename);   
        VR_VL = (VRcenter + VLcenter)/2;
        DR_DL = (DRcenter + DLcenter)/2;
        DL_VL = (DLcenter + VLcenter)/2;
        DR_VR = (DRcenter + VRcenter)/2;    

        k1 = (DR_VR(2)-DL_VL(2))/(DR_VR(1)-DL_VL(1));
        k2 = (DR_DL(2)-VR_VL(2))/(DR_DL(1)-VR_VL(1));


        center = (VRcenter + VLcenter + DRcenter + DLcenter)/4;

        save(coefDVLR_filename, 'VRcenter', 'VLcenter', 'DRcenter', 'DLcenter', 'DVLR', 'k1','k2','center'); 

    end; %    if exist(coefDVLR_filename) 
    close all;
end;   


%--------------------------------------
% recognize GFP cells
%--------------------------------------
% 
cntm = 0;

for testStack = testStackIdx
    

   cntm = cntm + 1;
   cnum = length(test.XPosAllb4{testStack});

    pl = []; 

   % -------------------------------------------------
   % identify muscle cells from the cell position list
   % -------------------------------------------------

   coefDVLR_filename = [testFilenamePrefix2{testStack}, '_coef_DVLR_new.mat'];
   load(coefDVLR_filename);
   
   clear segres;
   
   load(testGFPSegFilename{cntm}); % get segImg2
   
   if exist('segres','var') 
       if (size(segres,1)>size(segres,2))
           segImg2 = permute(segres, [2 1 3]);
       else
           segImg2 = segres;
       end;
   end;
   
   maxlabel = max(segImg2(:)); % label is continous

%    ----- method 1 -----   
   st = regionprops(segImg2, 'Centroid');

   for gfprgn=1:maxlabel


       kk = sub2ind(size(segImg2), test.YPosAllb4{testStack}, test.XPosAllb4{testStack}, test.ZPosAllb4{testStack});
       gfpcandidates = find(segImg2(kk)==gfprgn);


       if isempty(gfpcandidates)

           dtmp = sum((repmat(st(gfprgn).Centroid,[length(kk) 1]) - [test.XPosAllb4{testStack}', test.YPosAllb4{testStack}',test.ZPosAllb4{testStack}']).^2,2);
           [minval, minidx] = min(dtmp);
           gfpcells(gfprgn) = minidx;

       else

           if length(gfpcandidates)>1
               poscand = [(test.XPosAllb4{testStack}(gfpcandidates))', (test.YPosAllb4{testStack}(gfpcandidates))', (test.ZPosAllb4{testStack}(gfpcandidates))'];
               dist2center = sqrt(sum((poscand - repmat(st(gfprgn).Centroid,[size(poscand,1), 1])).^2,2)); 
               [minval, minidx] = min(dist2center);
               gfpcells(gfprgn) = gfpcandidates(minidx);
           else 
               gfpcells(gfprgn) = gfpcandidates; 
           end;
       end;

   end;


   XvalTest = test.XPosAllb4{testStack}(gfpcells);
   YvalTest = test.YPosAllb4{testStack}(gfpcells);
   ZvalTest = test.ZPosAllb4{testStack}(gfpcells);


    %--------------------------------------
    % identify VL23, VR24, DR24, DL24, Dep
    %--------------------------------------

    [sortval, sortidx] = sort(XvalTest);
    idx = sortidx(end-4:end);


    % classify ventral and dorsal

    ttt = zeros(size(segImg2,1), size(segImg2,3));
    ventralCells = [];
    dorsalCells = [];

    ttt2 = ttt; ttt2(:) = 0; % for debug purpose

    for i=1:length(idx)

        ttt(:) = 0;

        kk = find(segImg2 == idx(i)); % 20080703

        [y,x,z] = ind2sub(size(segImg2), kk);

        rr = sub2ind(size(ttt), y,z); % which first? Y or Z

        ttt(rr) = 1;

        ttt = ttt.*(DVLR+1); % VL:0;VR:1:DL:2; DR:3

        if ~isempty(intersect(unique(ttt),[3,4]))
            dorsalCells = union(dorsalCells, idx(i));
        else
            ventralCells = union(ventralCells, idx(i));
        end;

        ttt2 = ttt2 + ttt;
    end;

    dorsalCellNum = length(dorsalCells);
    ventralCellNum = length(ventralCells);

    % identify DL24, DR24, Dep

     if dorsalCellNum>=3

        [sortval, sortidx] = sort(XvalTest(dorsalCells), 'descend');
        dorsalCells = dorsalCells(sortidx(1:3));
        dorsalCellNum = length(dorsalCells);
	end;

    dcand = [117,116,118]; % dorsal candidates, from posteior to anterior
	
	switch length(dorsalCells)
        case 0
        case 1
            pl(:,1) = gfpcells(dorsalCells);
            pl(:,2) = 118;		
        case 2
            pl(:,1) = gfpcells(dorsalCells);
            pl(:,2) = [116, 118];					
        case 3	
           pl(:,1) = gfpcells(dorsalCells);
           pl(:,2) = [117, 116,118]; % dorsal candidates, from posteior to anterior
	end;

    % identify VL23, VR24

    len = length(pl);

    if ventralCellNum>=2
        [sortval, sortidx] = sort(XvalTest(ventralCells), 'descend');
        ventralCells = ventralCells(sortidx(1:2));
        ventralCellNum = length(ventralCells);
    end;

    pl(len+1:len+ventralCellNum,1) = gfpcells(ventralCells);

    if ventralCellNum == 1
        pl(len+1,2) = 112;
    else

        num = zeros(2,2);

        for i=1:ventralCellNum

            ttt(:) = 0;

            kk = find(segImg2 == ventralCells(i)); % 20080703

            [y,x,z] = ind2sub(size(segImg2), kk);

            rr = sub2ind(size(ttt), y,z); % which first? Y or Z

            ttt(rr) = 1;

            ttt = ttt.*(DVLR+1); % DVLR value: VL:0;VR:1:DL:2; DR:3, consistent with the order in cellTypeIdx2.mat

            num(i,1) = nnz(ttt==1);
            num(i,2) = nnz(ttt==2);

       end;

       num = num./repmat(sum(num,2),[1,2]); 

        if (num(1,1)+num(2,2)) > (num(1,2)+num(2,1))
            pl(len+1:len+2,2) = [112, 115];
        else 
            pl(len+1:len+2,2) = [115,112];
        end;
    end;

    if verifytag == 1,
        for i = 1:size(pl,1),
            idx = find(test.cellrecog(testStack,:)==pl(i,1));
            pl(i,3) = idx; % ground truth mapping 
        end;
    end;


    %--------------------------------------
    % assign the remaining GFP cells to 4 bundles
    %--------------------------------------

    idx = setdiff([1:length(gfpcells)], union(ventralCells, dorsalCells));

    BWMbundles = cell(1,4); % bundle 1: VL, 2: VR, 3:DL, 4:DR

    ttt2 = DVLR; ttt2(:) = 0;
    ra = zeros(length(gfpcells),3);
	
    for i=1:length(idx),
       
        ttt(:) = 0;

        kk = find(segImg2 == idx(i)); 

        [y,x,z] = ind2sub(size(segImg2), kk);

        rr = sub2ind(size(ttt), y,z); 

        ttt(rr) = 1;

        ttt = ttt.*(DVLR+1); % DVLR value: VL:0;VR:1:DL:2; DR:3, consistent with the order in cellTypeIdx2.mat

        ttt2 = ttt2 + ttt;
        
        num = zeros(1,4);

        for k=1:4,
            num(k) = nnz(ttt==k);
        end;

        [maxval, maxidx] = max(num);
		
        [sortval, sortidx] = sort(num);
        
        ra(idx(i),1) = sortval(3)/sortval(4); 
        ra(idx(i),2) = sortidx(3);
        ra(idx(i),3) = sortidx(4);
        
		BWMbundles{maxidx} = union(BWMbundles{maxidx}, idx(i)); 

    end;
    
    % test if the number of cells in the 4 bundles are correct
    stdCellNum = [18, 19, 20, 20]; 
    
    for bundle = 1: 4,
        
        extraCellNum = length(BWMbundles{bundle}) - stdCellNum(bundle);
        
        if extraCellNum > 0,
            
            [sortval, sortidx] = sort(ra(BWMbundles{bundle},1), 'descend');
            movedCells = BWMbundles{bundle}(sortidx(1:extraCellNum));
            BWMbundles{bundle} = setdiff(BWMbundles{bundle}, movedCells);
            bundleCand = ra(movedCells,2); 
            
            for j=1:extraCellNum,
                
                bundle2 = bundleCand(j); 
                BWMbundles{bundle2} = union(BWMbundles{bundle2}, movedCells(j));
                
            end;
            
        end;
            
    end;
    
    bundlename = {'VL', 'VR', 'DL', 'DR'};
    
    for bundle = 1: 4,
          fprintf('Bundle %s has %d cells\n',  bundlename{bundle}, length(BWMbundles{bundle}));
    end;

  
    %--------------------------------------
    % recognize the remaining GFP cells
    %--------------------------------------


    for bundle = 1:4,

        [sortval, sortidx] = sort(test.XPosAllb4{testStack}(gfpcells(BWMbundles{bundle})));
        BWMbundles{bundle} = BWMbundles{bundle}(sortidx); % adjust order according to AP 

        XvalTest = test.XPosAllb4{testStack}(gfpcells(BWMbundles{bundle}));
        lenTest = length(XvalTest);

        lenTraining = length(order{bundle})-1; % remove the very tail cell in each bundle

        if lenTest == lenTraining
            pairlist = repmat([1:lenTraining]', [1 2]); 

        else 

            pp = zeros(lenTest, lenTraining); 

            switch bundle,
                case 1,
                    tailCells = 112;
                case 2,
                    tailCells = 115;
                case 3,
                    tailCells = 117;
                case 4,
                    tailCells = 116;

            end;



            for trainingStack = 1:length(trainingStackIdx)

                XvalTraining = training.XPosb4(trainingStackIdx(trainingStack), setdiff(order{bundle}, tailCells)); 

                minval_global = Inf;

                iter = 0;

                while iter<20

                    iter = iter + 1;

                    CP = [];
                    tt = [];

                    for k=1:3
                        while (1)
                            tmp = round(rand(1)*lenTest);
                            if (tmp>=1)&(tmp<=min(lenTest,lenTraining))&(isempty(intersect(tmp, tt))),

                                break;
                            end;
                        end;
                        CP(k,1) = tmp;
                        tt = [tt,CP(k,1)];
                    end;



                    if lenTest > lenTraining
                        mm = max([CP(1,1)- (lenTest-lenTraining): CP(1,1)],1);
                        nn = max([CP(2,1)- (lenTest-lenTraining): CP(2,1)],1); 
                        kk = max([CP(3,1)- (lenTest-lenTraining): CP(3,1)],1); 

                    else
                        mm = min([CP(1,1) : CP(1,1) + (lenTraining-lenTest)],lenTraining);
                        nn = min([CP(2,1) : CP(2,1) + (lenTraining-lenTest)],lenTraining); 
                        kk = min([CP(3,1) : CP(3,1) + (lenTraining-lenTest)],lenTraining); 

                    end;

                    cnt = 0;
                    cost = [];
                    rec = [];
                    dd2 = [];
                    XvalTestNew2 = [];
                    pairlist2 = [];

                    for m = mm,

                        CP(1,2) = m;

                        for n = nn,

                            CP(2,2) = n;

                            for k = kk,

                                CP(3,2) = k;


                                    cnt = cnt + 1;

                                    Xtest = XvalTest(CP(:,1));
                                    Xtraining = XvalTraining(CP(:,2));


                                    AA = []; BB = [];
                                    AA(:,1) = XvalTest(CP(:,1))'; AA(:,2) = 1;
                                    BB = XvalTraining(CP(:,2))';

                                    CC = AA\BB;

                                    s = CC(1); t = CC(2);



                                    XvalTestNew = s*XvalTest + t;

                                     dd = abs(repmat(XvalTestNew',[1,lenTraining]) - repmat(XvalTraining, [lenTest,1]));

                                     [sortval, sortidx] = sort(dd,2);


                                     cost(cnt) = max(sortval(:,1));

                                    matching = hungarianC(dd);
                                    matching = (matching==0);
                                    pairlist = [];

                                    cnt2 = 0;
                                    cost2 = 0;

                                    for i=1:size(matching,1)
                                        j = find(matching(i,:)==1);
                                        if ~isempty(j)
                                            cnt2 = cnt2 + 1;
                                            pairlist(cnt2,:) = [i,j];
                                            cost2 = cost2 + dd(i,j);
                                        end;
                                    end;

                                    cost2 = cost2/cnt2;

                                    rec(cnt,1:5) = [m,n,k,cost(cnt),cost2];
                                    pairlist2(:,:,cnt) = pairlist;
                                    dd2(:,:,cnt) = dd;
                                    XvalTestNew2(:,cnt) = XvalTestNew;

                                    dt = [];
                                    for k=1:length(pairlist)
                                        dt(k) = dd(pairlist(k,1),pairlist(k,2));
                                    end;

                            end % for k end

                        end; % for n end
                    end; % for m end

                     [minval, minidx] = min(rec(:,5));


                    pairlist =   pairlist2(:,:,minidx);
                    dd = dd2(:,:,minidx);
                    XvalTestNew = XvalTestNew2(:,minidx);
                    mm = rec(minidx,1);
                    nn = rec(minidx,2);

                    rec;
                    pairlist;

                    if minval<minval_global
                        minval_global = minval;
                        pairlist_global = pairlist;
                    end;

                end; % while end

                pairlist = pairlist_global;

                for i=1:length(pairlist)
                    pp(pairlist(i,1), pairlist(i,2)) = pp(pairlist(i,1), pairlist(i,2)) + 1;
                end;

            end; % for trainingStackIdx end

            pp = 15-pp;

            matching = hungarianC(pp);
            matching = (matching==0);
            pairlist = [];

            cnt2 = 0;

            for i=1:size(matching,1),
                j = find(matching(i,:)==1);
                if ~isempty(j),
                    cnt2 = cnt2 + 1;
                    pairlist(cnt2,:) = [i,j];
                end;
            end;    

            pairlist;

        end; % if end


        % assign the real labels
        len = length(pl);
        lenp = length(pairlist);

        pl(len+1:len+lenp,1) = gfpcells(BWMbundles{bundle}(pairlist(:,1)));
        pl(len+1:len+lenp,2) = order{bundle}(pairlist(:,2)); % matching result

        if verifytag == 1,
            for i = 1:lenp,
                idx = find(test.cellrecog(testStack,:)==gfpcells(BWMbundles{bundle}(pairlist(i,1))));
                pl(len+i,3) = idx; % ground truth mapping 

            end;
        end;


    end; % for bundle = 1:4 end


    %--------------------------
    % write .apo file
    %--------------------------

	fn = [testFilenamePrefix1{testStack}, '.apo'];
	fnold = [testFilenamePrefix1{testStack}, '.old.apo'];
	
	copyfile(fn, fnold);
	
    linelist = loadfilelist(fnold); % read the annotation file of the current stack
    % cell no, cell no, cell name, comments, z, x, y, peakintensity, meanintensity, meanvalue, std, mass

	fid = fopen(fn, 'wt');
	
    countlines = 0;

    for i=1:length(linelist),
    %    i

       iterm = [];
        % parse each iterm
        if (~isempty(linelist{i}))

            j = 1;

            for mm = 1: itermno-1

                kstart = j; 

                while j<length(linelist{i})
                    if linelist{i}(j) == ','
                        kend = j-1;
                        break;
                    else
                        j = j + 1;
                    end;
                end;

                iterm{mm} = linelist{i}(kstart:kend); % each iterm is saved in string cell array

                j=j+1; 
            end;
            iterm{mm+1} = linelist{i}(j:end);
        end;

        len = length(iterm{3});

        if (strcmp(iterm{3}(1:min(len, 7)), '*NOUSE*')==0) 
            countlines = countlines + 1;
            hkk = find(pl(:,1) == countlines);

            if (~isempty(hkk))&(pl(hkk,2)~=0)&(isempty(iterm{3})) 
                iterm{3} = cellNameSet{pl(hkk(1),2)}; 
            else
                if isempty(iterm{3})
                    iterm{3} = '';
                end;
            end;

        end;

        if (isempty(iterm{3}))
            fprintf(fid, '%d,%d,%s,%s,%d,%d,%d,%5.2f,%5.2f,%5.2f,%5.3f,%5.3f\n', ...
            str2num(iterm{1}), str2num(iterm{2}), iterm{3},iterm{4}, round(str2num(iterm{5})), round(str2num(iterm{6})), round(str2num(iterm{7})), str2num(iterm{8}), str2num(iterm{9}), str2num(iterm{10}), str2num(iterm{11}),str2num(iterm{12})); 
        else
            fprintf(fid, '%d,%d,%s,%s,%d,%d,%d,%5.2f,%5.2f,%5.2f,%5.3f,%5.3f\n', ...
            str2num(iterm{1}), str2num(iterm{2}), iterm{3},['*autoanno*', iterm{4}], round(str2num(iterm{5})), round(str2num(iterm{6})), round(str2num(iterm{7})), str2num(iterm{8}), str2num(iterm{9}), str2num(iterm{10}), str2num(iterm{11}),str2num(iterm{12})); 
            
        end;
    end; % end of i
       
	fclose(fid);
              
end; % for testStack = testStackIdx


return;
