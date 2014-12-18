function batch_segmentationDAPI(idx, imgdatadir, DAPIdatadir, RFPdatadir, GFPdatadir, gfptag, rfptag, useGFPRFPtag)
% function batch_segmentationDAPI(idx, imgdatadir, DAPIdatadir, RFPdatadir, GFPdatadir, gfptag, rfptag, useGFPRFPtag)
%
% batch file for segmenting DAPI channel of worm stacks 
%
% Copyright F. Long
% Aug 11, 2008

for k=1:length(idx)
    i = idx(k);
    
    inimgname = [imgdatadir{i}, '_crop_straight_pre_DAPI.ics'];

    
    outimgname = [DAPIdatadir, num2str(i), '_segNucleiOrdered.mat'];    
    
    if (gfptag == 1)
        gfpsegimgname = [GFPdatadir, num2str(i), '_segNucleiOrdered.mat'];
    else
        gfpsegimgname = '';
    end;
    

    if (rfptag == 1)
        rfpsegimgname = [RFPdatadir, num2str(i), '_segNucleiOrdered.mat'];
    else
        rfpsegimgname = '';
    end;
    

    segNucleiDAPI(inimgname, outimgname, gfpsegimgname,  rfpsegimgname, useGFPRFPtag); % version give to Xiao

end;



