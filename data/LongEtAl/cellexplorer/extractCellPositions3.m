function extractCellPositions3(datadir,ind, locfilename, cellNameFile, cellnumanno, annotatedCellIdx)
% function extractCellPositions3(datadir,ind, locfilename, cellNameFile, cellnumanno,annotatedCellIdx)
% 
%
% extract X,Y,Z positions of each nucleus for all segmentated regions
%
% revised from extractCellPositions2.m, add parameter annotatedCellIdx,
% indicating which cells can be taken as already annotated. 
% F. Long
% 20080820

%-----------------------
% initialization and load files
%-----------------------

itermno = 12; % 12 iterms for each record
  
detectedPos = zeros(length(ind),cellnumanno); % record which cells are detected


XPosb4 = zeros(length(ind), cellnumanno);
YPosb4 = zeros(length(ind), cellnumanno);
ZPosb4 = zeros(length(ind), cellnumanno);
cellrecog = zeros(length(ind), cellnumanno);
                  
                  
% parse the cellNameSet

linelist = loadfilelist(cellNameFile);

count = 0;
cellNameSet = [];

for i=1:length(linelist)
    if (~isempty(linelist{i}))
        count = count + 1;
        cellNameSet{count}=linelist{i};

    end;
end;


for stack = 1:length(ind)
    
    %ind(stack)

    
    %-----------------------
    % load files
    %-----------------------

    % load annotation file
    filename = [datadir{ind(stack)},'.apo']; %'.ano.ano.txt']; 
    linelist = loadfilelist(filename); % read the annotation file of the current stack
    % cell no, cell no, cell name, comments, z, x, y, peakintensity, meanintensity, meanvalue, std, mass

    % load original image (for mass gravity computation)
    filename = [datadir{ind(stack)},'_crop_straight.raw'];  
    b = loadRaw2Stack(filename);
    b = permute(b, [2 1 3 4]);   
    b = b(:,:,:,3);
    
    % load segmentation mask image
    
    filename = [datadir{ind(stack)},'.ano.mask.raw']; 
    e = loadRaw2Stack(filename);
    f = permute(e, [2 1 3 4]);   


    %-------------------------------------------
    % compute cell positions using segmentation mask
    %-------------------------------------------
    
    gCenter = struct(measure(dip_image(f),  dip_image(b), {'gravity'}));
    t = [];
    
    for i=1:length(gCenter), 
        t(i,:)=round([gCenter(i).Gravity(1) gCenter(i).Gravity(2) gCenter(i).Gravity(3)]); % x,y,z
    end;


    cnti = 0;
    cnt = 0;
    nn = 0;
    
    num = length(linelist);
    hh = unique(f(f>0));
    rgnRemoved = setdiff([1:num], hh); % index of removed regions
        
    for i = 1:num
                
       iterm = [];
       
        % parse each iterm
        if (~isempty(linelist{i}))

            j = 1;

            for m = 1: itermno-1

                kstart = j; 

                while j<length(linelist{i})
                    if linelist{i}(j) == ','
                        kend = j-1;
                        break;
                    else
                        j = j + 1;
                    end;
                end;

                iterm{m} = linelist{i}(kstart:kend); % each iterm is saved in string cell array

                j=j+1; 
            end;
            iterm{m+1} = linelist{i}(j:end);
        end;

        len = length(iterm{3});
        curlabel = str2num(iterm{1});
        
        if (isempty(intersect(curlabel, rgnRemoved))) 

            if strcmp(iterm{3}(1:min(len, 7)), '*NOUSE*')==0             
                
                cnti = cnti + 1;

                cnt = find(hh== curlabel);
                XPosAllb4{stack}(cnti) = t(cnt,1);
                YPosAllb4{stack}(cnti) = t(cnt,2);
                ZPosAllb4{stack}(cnti) = t(cnt,3);
                
                lineNum{stack}(cnti) = i; 

                if (~isempty(iterm{3})) 
                    cellName = upper(iterm{3});
                    [CN, idx1, idx2] = intersect(upper(cellNameSet), cellName);


                    if (~isempty(idx1)) & (~isempty(intersect(idx1, annotatedCellIdx))) % used by extractCellPosition3.m

                        detectedPos(stack, idx1) = 1;

                        % annotated cells before normalization
                        XPosb4(stack, idx1) = XPosAllb4{stack}(cnti);
                        YPosb4(stack, idx1) = YPosAllb4{stack}(cnti);
                        ZPosb4(stack, idx1) = ZPosAllb4{stack}(cnti);

                        cellrecog(stack,idx1) = cnti; % 20080824 fix bug


                    end; %if (~isempty(idx1)) end

                end; %   if (~isempty(iterm{3})) end
                
            else % some region still exist in the mask image, while it is annotated as "*NOUSE*"
                
                cnt = cnt + 1; % discard the region in the segmentation mask
                nn = nn+1;
            end; % if strcmp(iterm{3}(1:min(len, 7)), '*NOUSE*')==0
            
        end; % if (isempty(intersect(str2num(iterm{1}), rgnRemoved)))
        
    end; %    for i = 1:num
    
    close all;
    
end;

save(locfilename, 'XPosAllb4', 'YPosAllb4', 'ZPosAllb4',...
                      'XPosb4', 'YPosb4', 'ZPosb4',...
                      'detectedPos', 'cellrecog', 'lineNum');  
save('cellrecog.mat', 'cellrecog');
                
return;