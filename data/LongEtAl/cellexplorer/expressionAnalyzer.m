function expressionAnalyzer(annofilenameprefix, ind, id_rfp, id_gfp, id_dapi)
% function expressionAnalyzer(annofilenameprefix, ind, id_rfp, id_gfp, id_dapi)
% 
% parse the annotation result file and generate the raw expression level (before any normalization) of
% GFP/RFP/DAPI channels. 

% F. Long

itermno = 12; % 12 iterms for each record


for stack = ind,
    
%     stack
    
    ExpLevelAllRFP = [];
    ExpLevelAllGFP = [];
    ExpLevelAllDAPI = [];
    cellVolume = [];
    
    count = 0;
    
    
    filename = [annofilenameprefix{stack},'.apo']; %.ano.ano.txt'];
    linelist = loadfilelist(filename); % read the annotation file of the current stack

    % cell no, cell no, cell name, comments, z, x, y, peakintensity, meanintensity, meanvalue, std, mass

    filename = [annofilenameprefix{stack},'.ano.mask.raw'];                
    a = loadRaw2Stack(filename);
    a = permute(a, [2 1 3]);
    stat = regionprops(a,'PixelIdxList', 'Area');
	
    % load original image
    filename = [annofilenameprefix{stack},'_crop_straight.raw'];                
    b = loadRaw2Stack(filename);
    b = permute(b, [2 1 3 4]);   
    
    tmp1 = squeeze(b(:,:,:,id_rfp));
    tmp2 = squeeze(b(:,:,:,id_gfp));
    tmp3 = squeeze(b(:,:,:,id_dapi));    
    
    cellcnt = 0;
    
    for i=1:length(linelist)
    %    i

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
            
            if ~isempty(iterm{3})
                if strcmp(iterm{3}(1:min(7,end)), '*NOUSE*') ==1
                    continue;
                end;
            end;
            
            % test if a line consists of all 0, if yes, that line is an
            % artificial line, which is added in recogcell_dapi2, in order
            % for vano to display
            sumval = 0;
            for m=5:itermno
                sumval = sumval+str2num(iterm{m});
                
            end;
            
            if (sumval==0) 
                continue;
            else

                cellcnt=cellcnt+1;
                ExpLevelAllRFP(cellcnt) = sum(tmp1(stat(str2num(iterm{1})).PixelIdxList));
                ExpLevelAllGFP(cellcnt) = sum(tmp2(stat(str2num(iterm{1})).PixelIdxList));
                ExpLevelAllDAPI(cellcnt) = sum(tmp3(stat(str2num(iterm{1})).PixelIdxList));
                cellVolume(cellcnt) = stat(str2num(iterm{1})).Area;
            end;
        end;
    end;
    
%     % save files
    filename_rfp = [annofilenameprefix{stack}, '_expLevelRFP.txt'];
    fid_rfp = fopen(filename_rfp, 'wt');
    
    filename_gfp = [annofilenameprefix{stack}, '_expLevelGFP.txt'];
    fid_gfp = fopen(filename_gfp, 'wt');
    
    filename_dapi = [annofilenameprefix{stack}, '_expLevelDAPI.txt'];
    fid_dapi = fopen(filename_dapi, 'wt');

    filename_cellvol = [annofilenameprefix{stack}, '_cellVolume.txt'];
    fid_cellvol = fopen(filename_cellvol, 'wt');
    
    
    for i=1:cellcnt
        fprintf(fid_rfp, '%s\n',num2str(ExpLevelAllRFP(i)));
        fprintf(fid_gfp, '%s\n',num2str(ExpLevelAllGFP(i)));
        fprintf(fid_dapi, '%s\n',num2str(ExpLevelAllDAPI(i)));
        fprintf(fid_cellvol, '%s\n',num2str(cellVolume(i)));
       
    end;

    fclose(fid_rfp); fclose(fid_gfp); fclose(fid_dapi); fclose(fid_cellvol);
    fprintf('\n');
    fprintf('The RFP gene expression of all cells for stack %d has ben saved to the text file [%s]\n', stack, filename_rfp); 
    fprintf('The GFP gene expression of all cells for stack %d has ben saved to the text file [%s]\n', stack, filename_gfp); 
    fprintf('The DAPI gene expression of all cells for stack %d has ben saved to the text file [%s]\n', stack, filename_dapi); 
    fprintf('The Volume of all cells for stack %d has ben saved to the text file [%s]\n', stack, filename_cellvol); 
   
end;

