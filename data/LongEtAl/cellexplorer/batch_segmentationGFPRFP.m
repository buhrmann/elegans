function batch_segmentationGFPRFP(idx, indatadir, GFPoutdatadir, RFPoutdatadir, GFPtag, RFPtag);
% function batch_segmentationGFPRFP(idx, indatadir, GFPoutdatadir, RFPoutdatadir, GFPtag, RFPtag);
% 
% GFPtag =1: segment GFP channel, otherwise do not segment and ignore GFPoutdatadir
% RFPtag =1: segment RFP channel, otherwise do not segment and ignore RFPoutdatadir
% 
% Copyright F. Long


for k=1:length(idx)
    i = idx(k);

    if (GFPtag ==1)    
        inimgname1 = [indatadir{i}, '_crop_straight_pre_GFP.ics']; 
        inimgname2 = [indatadir{i}, '_crop_straight_pre_DAPI.ics'];
        outimgname = [GFPoutdatadir, num2str(i), '_segNucleiOrdered.mat'];   
        fprintf('Segment GFP channel ...\n');
        segNucleiGFP(inimgname1, inimgname2, outimgname, 82, 1);        
    end;
      
      
    if (RFPtag == 1)
        inimgname1 = [indatadir{i}, '_crop_straight_pre_RFP.ics']; 
        inimgname2 = [indatadir{i}, '_crop_straight_pre_DAPI.ics'];
        outimgname = [RFPoutdatadir, num2str(i), '_segNucleiOrdered.mat'];    
        fprintf('Segment RFP channel ...\n');
        segNucleiGFP(inimgname1, inimgname2, outimgname, 999, 1);        
    end;
    

end;
