function recogcells_dapi2(datadir, graphTag, graphfilename, locPatTestFilename, locPatTrainingFilename, reglocPatTrainingFilename, testStackIdx, trainingStackIdx, annofilenameprefix, cellNameFile, annoCellnum, annotatedCellIdx)
% function recogcells_dapi2(datadir, graphTag, graphfilename, locPatTestFilename, locPatTrainingFilename, reglocPatTrainingFilename, testStackIdx, trainingStackIdx, annofilenameprefix, cellNameFile, annoCellnum )
% automatically recognize the remaining cells (excluding muscle cells) in DAPI channel 
% 
% copyright: F. Long
% 20080819

%---------------------------------------------------------------------
% extract cell positions for test stacks
%---------------------------------------------------------------------
     
extractCellPositions3(annofilenameprefix, testStackIdx, locPatTestFilename, cellNameFile, annoCellnum, annotatedCellIdx);  

% --------------
% initialization
% --------------

test = load(locPatTestFilename); % locations of cells in the test data
trainingb4reg = load(locPatTrainingFilename); % locations of the training data before registration
training = load(reglocPatTrainingFilename); % locations of the training data after registration


musclecell = [37:118]; 
musclecellnum = length(musclecell); 
nonmusclecell = setdiff([1:annoCellnum],musclecell);
cellind = nonmusclecell;
cellnum = length(cellind);


stackind4graph = trainingStackIdx; % index of stacks used to build atlas

teststacknum = length(testStackIdx);
trainstacknum = length(trainingStackIdx);

regref = 1; % the reference stack in the training set to which the test stacks should be registered to

load 'training_data/cellTypeIdx2.mat';


%-----------------------------------------------------
% load cell name for filling .ano.ano.txt file purpose
%-----------------------------------------------------

count = 0;
cellNameSet = [];
linelist = loadfilelist(cellNameFile);

for i=1:length(linelist)
    if (~isempty(linelist{i}))
        count = count + 1;
        cellNameSet{count}=linelist{i};

    end;
end;

itermno = 12;

%---------------------------------------------
% load or compute APDVLR graph of training set
%---------------------------------------------

if exist(graphfilename) 
    load(graphfilename); 
else 
    cellPos = training.allPts{regref};
    [rgM, rgMStacks] = compute_APDVLRgraph(annoCellnum, cellPos);
    save(graphfilename, 'rgM', 'rgMStacks');
end;


%----------------------------------------------------------------------
% identfiy AP bound of each cell in the training set, 
% i.e., find 8 marker cells, with 2 on each bundle, the cell
% in consideration should sit in between those 8 markers using training
% stacks, except for some head and tail cells who may be
% anterior or posterior to all muscle cells
%----------------------------------------------------------------------

markernum = 4;
APbound = zeros(cellnum, 8); % 2 cells in each bundle of the BWM

for cellref = 1:cellnum

    for marker =1:markernum % four bundles of BWM

        idx = [cellind(cellref), order{marker}];

        anteriorIdx = order{marker};
        posteriorIdx = order{marker};

        for stack = 1:trainstacknum
            if (sum(training.allPts{regref}(idx(1),:,stack))==0)
                continue;
            else
                [sortval, sortidx] = sort(training.allPts{regref}(idx,1,stack));
                ind = find(sortidx==1); % 1 is cellinf(cellref)
                anteriorIdx = intersect(anteriorIdx, idx(sortidx(1:ind-1)));
                posteriorIdx = intersect(posteriorIdx, idx(sortidx(ind+1:end)));
            end;
        end;

        if isempty(anteriorIdx)
            m1 = 0; % set 0 to those markers not detected, this happens for the very head and very tail cells
        else
            m1 = anteriorIdx(end);
        end;

        if isempty(posteriorIdx)
            m2 = 0;
        else
            m2 = posteriorIdx(1);
        end;


        APbound(cellref, 2*marker-1:2*marker) = [m1, m2]; 
    end;
end;


%--------------------------------------------------------------
% compute pair-wise AP/LR/DV distance matrices from training data
%--------------------------------------------------------------

APDVLRdisMarker = zeros(cellnum, 8, 3, trainstacknum);

stackcnt = 0;

for stack = 1:trainstacknum

    for cellref = 1:cellnum

        if sum(training.allPts{regref}(cellind(cellref), :, stack))==0 % cellind(cellref) not detected
            APDVLRdisMarker(cellref, :,:, stack) = NaN;
        else

            for kk = 1:8
                if (APbound(cellref,kk) == 0)
                    APDVLRdisMarker(cellref, kk,:, stack) = NaN;
                else
                    APDVLRdisMarker(cellref, kk,:, stack) = training.allPts{regref}(APbound(cellref, kk), :, stack) - training.allPts{regref}(cellind(cellref), :, stack);
                end;

            end;
        end;
    end;
end;



%-----------------------------------------------
% compute the mean and std matrices of APDVLRdisMarker
%-----------------------------------------------

meanMatrix = zeros(cellnum, size(APDVLRdisMarker,2), 3);
stdMatrix = zeros(cellnum, size(APDVLRdisMarker,2), 3);

APDVLR =  permute(APDVLRdisMarker, [1 2 4 3]);
tag = ~isnan(APDVLR);
iii = find(isnan(APDVLR));
APDVLR(iii) = 0;

tmp1 = squeeze(sum(APDVLR .* tag,3));
tmp2 = squeeze(sum(tag,3));

iii = find(tmp2==0);
meanMatrix(iii) = 0;
stdMatrix(iii) = 0;

iii = setdiff([1:cellnum*size(APDVLRdisMarker,2)*3], iii);
meanMatrix(iii) = tmp1(iii)./tmp2(iii);

tmp = zeros(cellnum, size(APDVLRdisMarker,2), 1, 3);
tmp(:,:,1,:) = meanMatrix;
tmp1 = squeeze(sum(((APDVLR-repmat(tmp, [1,1, size(APDVLR,3),1])).^2).*tag,3));
tmp2 = squeeze(sum(tag, 3)-1);
stdMatrix(iii) = sqrt(tmp1(iii)./tmp2(iii));


% -----------------------------------------------------------------
% generate relations of interest based on KNN, used for computing
% contradict matrix
% -----------------------------------------------------------------

RI = zeros(annoCellnum);

disThre = 20;

myKNN = cell(1, 357);

for i=1:trainstacknum

    ddInStack = sqrt(dist2(training.allPts{regref}(:,:,i), training.allPts{regref}(:,:,i)));
    notDetectedIdx = find(sum(squeeze(training.allPts{regref}(:,:,i)),2)==0);
    ddInStack(notDetectedIdx,:) = 99999;
    ddInStack(:,notDetectedIdx) = 99999;

    [sortval, sortidx] = sort(ddInStack,2);
    for j=1:357
        iidx = find(sortval(j,:)<disThre);
        myKNN{j} = union(myKNN{j}, sortidx(j,iidx));
    end;
end;


for i=1:357
    RI(myKNN{i},myKNN{i}) = 1;
end;
    
    

% ------------------------------
% two stage bipartite matching
% ------------------------------

for teststack = testStackIdx
    

    fprintf('current test stack index = %d\n', teststack);

    %---------------------------------------------------------------------
    % identify annotated and non-annotated cells
    %---------------------------------------------------------------------
   
    idxx0 = setdiff(test.cellrecog(teststack, :),0); % index of the segmentated regions of all the annotated cells
    nn1 = find(test.cellrecog(teststack,:)>0); % index of annotated cells in the 357 cells to be annotated

   
    %-------------------------------------------------------------------
    % register test stack against the reference training stack (to which
    % all the remaining training stack is registered)
    %-------------------------------------------------------------------
    
    regfilename = [datadir{teststack}, '_alignedCellPos.mat'];
    
    if ~exist(regfilename)
    
        Pos_cpt_test = [];

        Pos_cpt_test(:,1) = test.XPosb4(teststack,musclecell); % may contain muscle cells not detected or annotated
        Pos_cpt_test(:,2) = test.YPosb4(teststack,musclecell);
        Pos_cpt_test(:,3) = test.ZPosb4(teststack,musclecell);


        % generate the controlling points of the reference stack in the training set
        Pos_cpt_training = [];

        Pos_cpt_training(:,1) = trainingb4reg.XPosb4(trainingStackIdx(regref),musclecell);
        Pos_cpt_training(:,2) = trainingb4reg.YPosb4(trainingStackIdx(regref),musclecell);
        Pos_cpt_training(:,3) = trainingb4reg.ZPosb4(trainingStackIdx(regref),musclecell);

        % generate the common controlling points for test and training stacks
        ind = find((Pos_cpt_test(:,1)>0)&(Pos_cpt_training(:,1)>0));
        targetCpt = Pos_cpt_training(ind, :); % x,y,z
        subjectCpt = Pos_cpt_test(ind, :); % x,y,z

        % generate points of the test stack
        Pos_test = [];
        Pos_test(:,1) = test.XPosAllb4{teststack};
        Pos_test(:,2) = test.YPosAllb4{teststack};
        Pos_test(:,3) = test.ZPosAllb4{teststack};

        % generate subject points

        subjectPts = zeros(size(Pos_test,1),3);
        ind = find(Pos_test(:,1)>0);
        subjectPts(ind,:) = Pos_test(ind, :); % x,y,z


        targetImg = [];
        subjectImg = [];

        % register subject stack to target stack
        [transImg,transPtsTmp, T,xdata,ydata,zdata] = affineTransImg3D(targetImg, subjectImg, targetCpt, subjectCpt,subjectPts(ind,:),0,0);

        alignedTestCellPos = Pos_test;
        alignedTestCellPos(:) = 0;
        alignedTestCellPos(ind,:) = transPtsTmp;

        save(regfilename, 'alignedTestCellPos'); 
    else
        load(regfilename); % get matrix alignedTestCellPos
    end;
    
    
    testStackCellInd = setdiff([1:length(alignedTestCellPos)],idxx0); % cells that have not been annotated
    testCellnum = length(testStackCellInd);
    
    testStackCellAnnoInd = intersect(cellind, setdiff([1:annoCellnum], find(test.cellrecog(teststack,:)>0)));   %20080827
    
    testStackCellAnnoIdx = [];
    for i=1:length(testStackCellAnnoInd)
        testStackCellAnnoIdx(i) = find(cellind == testStackCellAnnoInd(i)); % index of cells in 276 non-muscle cells
    end;
    
    %---------------------------------------------------------------------------
    % compute AP/LR/DV distance matrices of test stack, set distance to NaN when not available
    %---------------------------------------------------------------------------

    testdis = zeros(testCellnum, musclecellnum, 3);
    
    for cellref = 1:testCellnum

        for kk = 1:musclecellnum

            if (test.cellrecog(teststack,kk+36) == 0) % the marker is not detected
                testdis(cellref, kk, :) = NaN;
            else
                testdis(cellref, kk, :) = alignedTestCellPos(test.cellrecog(teststack,kk+36), :) - alignedTestCellPos(testStackCellInd(cellref), :);
            end;

        end;
        
    end;
    
    % ------------------------------------------------------------------
    % get the initial mapping using BWM-marker based + bipartite matching 
    % ------------------------------------------------------------------
    
    cnt = 0;

    dd = zeros(length(testStackCellAnnoIdx),testCellnum);

    % calculate the mean locations of 357 annotated cells
    tmp1 = squeeze(training.allPts{regref});
    meanCellPos = sum(tmp1,3)./sum((tmp1>0),3);

    
    for cellref = testStackCellAnnoIdx 
        cost = zeros(1, testCellnum);

        cnt = cnt + 1;

        for testcellref = 1:testCellnum

            meanval = squeeze(meanMatrix(cellref,:,:));
            stdval = squeeze(stdMatrix(cellref,:,:));            

            idxx = find(APbound(cellref,:)==0); % most anteior or most posterior cells
            
            b(idxx,1) = NaN;

            idxx = setdiff(1:2*markernum, idxx);
            b(idxx,1) = (squeeze(testdis(testcellref,APbound(cellref,idxx)-36,1)))';

            bTag0(:,1) = ~isnan(b(:,1));

            for i=2:3

                idxx = find(APbound(cellref,:)==0);
                b(idxx,i) = NaN;
                idxx = setdiff(1:2*markernum, idxx);
                b(idxx,i) = (squeeze(testdis(testcellref,APbound(cellref,idxx)-36,i)))';

                bTag0(:,i) = ~isnan(b(:,i));

            end;

            hhh = find(stdval==0);
 
            tmp1 = abs(b-meanval);
            tmp = meanval;
            tmp(:) = 0;
            hhh = intersect(setdiff([1:markernum*2*3],hhh),find(bTag0>0));
            tmp(hhh) = tmp1(hhh)./stdval(hhh);
            cost(testcellref) = sum(tmp(:))/nnz(tmp);

        end; % for testcellref end
                      
        dd(cnt, :) = cost;
    end;


    matching = hungarianC(dd);
    matching = (matching==0);
    pl = [];
    
    cnt = 0;
    for i=1:size(matching,1)
        j = find(matching(i,:)==1);
        if ~isempty(j)
            cnt = cnt + 1;                
            pl(cnt,:) = [testStackCellAnnoInd(i), testStackCellInd(j)];
            
        end;

    end;
 
   
    % ---------------------------------------------------------------------
    % generate APDVLR adjacency matrix for matching result and search for
    % wrong matches by comparing it against the template adjacency matrix
    % ---------------------------------------------------------------------

   
    iter = 0;    
    metricvalmin = Inf;

    llen = nnz(test.cellrecog(teststack, :)>0); % number of cells already annotated
    annoii = find(test.cellrecog(teststack,:)>0); % index of cells already annotated
    
    while (1)
    
        iter = iter + 1;
        fprintf('current iteration = %d\n', iter);
        
        %generate APDVLR adjacency matrix for the test stack based on the biparite matching result

        % add back cells already annotated
        
        len = length(pl);
        plAll = pl;
        
        
        plAll(len+1:len+llen,1) = annoii;        
        plAll(len+1:len+llen,2) = test.cellrecog(teststack, annoii);

        if iter==1
            plAllb4 = plAll;
        end;
        
        dataMtest = [];
        dataMtest(:,1) = squeeze(alignedTestCellPos(plAll(:,2),1))';
        dataMtest(:,2) = squeeze(alignedTestCellPos(plAll(:,2),2))';
        dataMtest(:,3) = squeeze(alignedTestCellPos(plAll(:,2),3))';

        posteriorM = zeros(annoCellnum,annoCellnum,3);

        for i = 1:3

            [sortval, sortidx] = sort(dataMtest(:,i)); 

            for j=1:length(plAll)
                if (~isempty(sortidx(j+1:end)))

                    jjj = sortidx(j+1:end);

                    posteriorM(plAll(sortidx(j),1), plAll(jjj,1),i) = 1;

                end;
            end;
        end;


        % for those not detected cells, no relationship with other cells

        nn = setdiff([1:annoCellnum],plAll(:,1));
        posteriorM(:,nn,:) = 0; % cells not detected, assume no contradition
        posteriorM(nn,:,:) = 0;

        % relax APDVLR relationship: if two cells are too close in a dimension,
        % make them no relationship
        threval = [2 2 2];

        tmp = posteriorM;
        tmp(:) = 1;

        lenplAll = size(plAll,1);
        
        plAllsorted = plAll;
        [sortval, sortidx] = sort(plAll,1);
        plAllsorted = plAll(sortidx(:,1),:); 

        diffthreAll = zeros(annoCellnum,3);
        
        for i=1:lenplAll
            diff = abs(repmat(alignedTestCellPos(plAllsorted(i,2),:),[lenplAll 1 1]) - alignedTestCellPos(plAllsorted(:,2),:));
            diffthre = (diff < repmat(threval, [lenplAll 1]));
            diffthreAll(plAllsorted(:,1),:) = diffthre;
            tmp(plAllsorted(i,1),:,:) = (diffthreAll==0);
        end;

        posteriorM = tmp .* posteriorM;        

        % search for conflict
        contradict = zeros(size(rgM,1), size(rgM,2));
        for i=1:size(rgM,3)

            aa = squeeze(rgM(:,:,i));
            bb = squeeze(posteriorM(:,:,i));
            contradict = contradict | (aa .* (~aa').* (~bb).*bb')  | (~aa) .* (aa').* bb.* (~bb');

        end;

        contradict = contradict .* RI;
        
        metricval{teststack}(iter) =nnz(contradict);
   
        if metricval{teststack}(iter)<metricvalmin
            metricvalmin = metricval{teststack}(iter);
        end;
        

        nn = sum(contradict,2);
        [maxval, maxidx] = max(nn);

        if maxval>1

            iidx = find(nn==maxval);

            for i=1:length(iidx)

                iii = find(plAll(:,1)==iidx(i));

                ia = find(testStackCellAnnoInd== plAll(iii,1));
                ib = find(testStackCellInd == plAll(iii,2));

                dd(ia,ib) = 999;

            end;
        else

            break;

        end;

        % do bipartite matching again

        matching = hungarianC(dd);
        matching = (matching==0);
        pl = [];
        
        cnt = 0;
        for i=1:size(matching,1)
            j = find(matching(i,:)==1);
            if ~isempty(j)
                cnt = cnt + 1;

                iii = find(testStackCellInd(j) == test.cellrecog(teststack,:));
                
               
                pl(cnt,:) = [testStackCellAnnoInd(i), testStackCellInd(j)];

            end;

        end;
        
        if iter>20
            break
        end;
        
    end; % while (1)   
   
    len = length(pl);
    plAll = pl;


    plAll(len+1:len+llen,1) = annoii;        
    plAll(len+1:len+llen,2) = test.cellrecog(teststack, annoii);

    filename = [annofilenameprefix{teststack}, '.recog.mat'];
    save(filename, 'plAll'); 
    
    % -----------------------
    % write .ano.ano.txt file
    % -----------------------
    

	fn = [annofilenameprefix{teststack}, '.apo']; %'.ano.ano.txt'];
  	fn2 = [annofilenameprefix{teststack}, '.b4adjust.apo']; %'.b4adjust.ano.ano.txt'];
  
    bb = 2;
    fnold = [annofilenameprefix{teststack}, '.old', num2str(bb),'.apo']; %'.ano.ano.txt'];
    
    while (exist(fnold))
        bb = bb + 1;
        fnold = [annofilenameprefix{teststack}, '.old', num2str(bb),'.apo'];%'.ano.ano.txt'];
    end;
	
	copyfile(fn, fnold);
	
    linelist = loadfilelist(fnold); % read the annotation file of the current stack
    % cell no, cell no, cell name, comments, z, x, y, peakintensity, meanintensity, meanvalue, std, mass

	fid = fopen(fn, 'wt'); % annotation after APDVLR adjust
    fid2 = fopen(fn2,'wt'); % annotation before APDVLR adjust
	
   
    linelen = length(test.lineNum{teststack}); 
    
    lastlabel = 0;
    
    for vv=1:linelen

        i = test.lineNum{teststack}(vv); % the ith line in the old .ano.ano.txt file
        
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
        
        % after APDVLR adjust
        hkk = find(plAll(:,2) == vv);
            
        if (~isempty(hkk))
            iterm{3} = cellNameSet{plAll(hkk,1)};
        end;
        
        
        % fill-in blank lines
        
        curlabel = str2num(iterm{2});
        
        if ((curlabel-lastlabel)>1)
            for kkk = lastlabel+1:curlabel-1
                fprintf(fid, '%d,%d,0,0,0,0,0,0,0,0,0,0\n', kkk,kkk); 
                fprintf(fid2, '%d,%d,0,0,0,0,0,0,0,0,0,0\n', kkk,kkk); 
            end;
		end;
		
		 lastlabel = curlabel;

        if (~isempty(intersect(annoii,plAll(hkk,1))))
           fprintf(fid, '%d,%d,%s,%s,%d,%d,%d,%5.2f,%5.2f,%5.2f,%5.3f,%5.3f\n', ...
           str2num(iterm{2}),str2num(iterm{2}), iterm{3},iterm{4}, round(str2num(iterm{5})), round(str2num(iterm{6})), round(str2num(iterm{7})), str2num(iterm{8}), str2num(iterm{9}), str2num(iterm{10}), str2num(iterm{11}),str2num(iterm{12})); 
        else
            if (~isempty(hkk))
               fprintf(fid, '%d,%d,%s,%s,%d,%d,%d,%5.2f,%5.2f,%5.2f,%5.3f,%5.3f\n', ...
               str2num(iterm{2}),str2num(iterm{2}), iterm{3},['*autoanno* ',iterm{4}], round(str2num(iterm{5})), round(str2num(iterm{6})), round(str2num(iterm{7})), str2num(iterm{8}), str2num(iterm{9}), str2num(iterm{10}), str2num(iterm{11}),str2num(iterm{12})); 
            else
               fprintf(fid, '%d,%d,%s,%s,%d,%d,%d,%5.2f,%5.2f,%5.2f,%5.3f,%5.3f\n', ...
               str2num(iterm{2}),str2num(iterm{2}), iterm{3},iterm{4}, round(str2num(iterm{5})), round(str2num(iterm{6})), round(str2num(iterm{7})), str2num(iterm{8}), str2num(iterm{9}), str2num(iterm{10}), str2num(iterm{11}),str2num(iterm{12})); 
                
            end;
        end;

       % before APDVLR adjust

        hkk = find(plAllb4(:,2) == vv);

        if (~isempty(hkk))
            iterm{3} = cellNameSet{plAllb4(hkk,1)};
        end;

        if (~isempty(intersect(annoii,plAll(hkk,1))))
           fprintf(fid2, '%d,%d,%s,%s,%d,%d,%d,%5.2f,%5.2f,%5.2f,%5.3f,%5.3f\n', ...
           str2num(iterm{2}),str2num(iterm{2}), iterm{3},iterm{4}, round(str2num(iterm{5})), round(str2num(iterm{6})), round(str2num(iterm{7})), str2num(iterm{8}), str2num(iterm{9}), str2num(iterm{10}), str2num(iterm{11}),str2num(iterm{12})); 
        else 
            if (~isempty(hkk))
                fprintf(fid2, '%d,%d,%s,%s,%d,%d,%d,%5.2f,%5.2f,%5.2f,%5.3f,%5.3f\n', ...
                str2num(iterm{2}),str2num(iterm{2}), iterm{3},['*autoanno* ',iterm{4}], round(str2num(iterm{5})), round(str2num(iterm{6})), round(str2num(iterm{7})), str2num(iterm{8}), str2num(iterm{9}), str2num(iterm{10}), str2num(iterm{11}),str2num(iterm{12})); 
            else
               fprintf(fid2, '%d,%d,%s,%s,%d,%d,%d,%5.2f,%5.2f,%5.2f,%5.3f,%5.3f\n', ...
               str2num(iterm{2}),str2num(iterm{2}), iterm{3},iterm{4}, round(str2num(iterm{5})), round(str2num(iterm{6})), round(str2num(iterm{7})), str2num(iterm{8}), str2num(iterm{9}), str2num(iterm{10}), str2num(iterm{11}),str2num(iterm{12})); 
                
            end;
        end;            
  

    end; % end of vv
    
    fclose(fid);
    fclose(fid2);
            
end; % teststack


return;
