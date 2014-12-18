function segNucleiDAPI(inimgname, outimgname, gfpsegimgname, rfpsegimgname, useGFPRFPtag)
% function segNucleiDAPI(inimgname, outimgname, gfpsegimgname, rfpsegimgname, useGFPRFPtag)
% Segmente nuclei in DAPI channel
%
% Copyright F. Long
% Aug 11, 2008

% ------------------------------
% parameter initialization
% ------------------------------

overlap_winwid = 20;
rgnMinSize = 100;
rgnConvexity = 0.85;

GFPsegMask = [];
RFPsegMask = [];


% ---------------
% read image
% ---------------

% load DAPI channel
inimg = uint8(readim(inimgname)); % read original image

% load GFP segmentation results
if (~isempty(gfpsegimgname))
    load(gfpsegimgname);
	if (size(segres,1) > size(segres,2))
		segres = permute(segres,[2,1,3]);
	end;
	GFPsegMask = segres;
end;

% load RFP segmentation results
if (~isempty(rfpsegimgname))
    load(rfpsegimgname);
	if (size(segres,1) > size(segres,2))
		segres = permute(segres,[2,1,3]);
	end;
    RFPsegMask = segres;    
end;

% ---------------------------------------------------------------------
% detecting boundary of head, trunk and tail, cut the image into head,
% trunk, and tail parts
% ---------------------------------------------------------------------


while (1)
    
    dip_image(sum(inimg,3))

    fprintf('Click two points indicating the cutting position between 1) head/trunk, 2) trunk/tail\n');

    [X,Y] = ginput(2);

    posHead = min(X);
    posTail = max(X);


    XX0 = [X(1), X(1)];
    YY0 = [1,size(inimg,1)];
    hold on; line(XX0, YY0, 'Color','r');

    XX0 = [X(2), X(2)];
    hold on; line(XX0, YY0, 'Color','r');
    
    ps = input('Are they correct cutting lines (y/n) ','s');
    close all;
    
    if strcmp(ps,'y')==1
        break;
    end;
end;

 

% ------------------------------
% segment trunk part
% ------------------------------

fprintf('Segmenting trunk...\n');

% trunk image
inimg1 = inimg(:,posHead-overlap_winwid:posTail,:);

if (~isempty(GFPsegMask))
    GFPsegImg = GFPsegMask(:,posHead-overlap_winwid:posTail,:);
else
    GFPsegImg = [];
end;

if (~isempty(RFPsegMask))
    RFPsegImg = RFPsegMask(:,posHead-overlap_winwid:posTail,:);
else
    RFPsegImg = [];
end;


rgnMaxSize = 4500; 

[trunk_segImg2, trunk_rgnSeg,sesize] = segTrunk(inimg1, rgnMinSize, rgnConvexity, GFPsegImg, RFPsegImg,rgnMaxSize,useGFPRFPtag);
save(outimgname, 'trunk_segImg2', 'trunk_rgnSeg');


% ------------------------------
% segment Tail part
% ------------------------------

fprintf('Segmenting tail...\n');

% tail image
inimg1 = inimg(:,posTail-overlap_winwid:end,:);
if (~isempty(GFPsegMask))
    GFPsegImg = GFPsegMask(:,posTail-overlap_winwid:end,:);
else
    GFPsegImg = [];
end;

if (~isempty(RFPsegMask))
    RFPsegImg = RFPsegMask(:,posTail-overlap_winwid:end,:);
else 
    RFPsegImg = [];
end;


rgnMaxSize = 2500; 

[tail_segImg2, tail_rgnSeg] = segTail(inimg1, rgnMinSize, rgnConvexity, GFPsegImg, RFPsegImg,rgnMaxSize, useGFPRFPtag, sesize);
save(outimgname, 'tail_rgnSeg', 'tail_segImg2', 'trunk_segImg2', 'trunk_rgnSeg');
 
% ------------------------------
% segment head part
% ------------------------------

fprintf('Segmenting head...\n');

% head image
inimg1 = inimg(:,1:posHead,:);
if (~isempty(GFPsegMask))
    GFPsegImg = GFPsegMask(:,1:posHead,:);
else 
    GFPsegImg = [];
end;

if (~isempty(RFPsegMask))
    RFPsegImg = RFPsegMask(:,1:posHead,:);
else
    RFPsegImg = [];
end;

dip_image(inimg1);

rgnMaxSize = 2500;
[head_segImg2, head_rgnSeg] = segTail(inimg1, rgnMinSize, rgnConvexity, GFPsegImg, RFPsegImg,rgnMaxSize, useGFPRFPtag, sesize);
save(outimgname, 'head_segImg2', 'head_rgnSeg', 'tail_segImg2', 'tail_rgnSeg', 'trunk_segImg2', 'trunk_rgnSeg');


% --------------------------------------------
% combine head, trunk, and tail segmentation
% --------------------------------------------

fprintf('Combining head, trunk, and tail...\n');

sz = size(inimg);
segres = segNucleiDAPI_combine_headtrunktail(sz,posHead, posTail,overlap_winwid, head_segImg2, trunk_segImg2, tail_segImg2);


% ------------------------------------------------------
% make label continous, sort regions along AP axis
% ------------------------------------------------------

fprintf('Sorting regions...\n');

% make label continuous
minsz = 0;
[rgnSeg,segres] = rgnStat3(inimg, uint16(segres), minsz,1,0); % compute region properties and discard very small regions 

rgn = regionprops(segres,'PixelIdxList');
r = struct(measure(uint16(segres), uint16(inimg), {'gravity'}));

rgnnum = length(rgnSeg);
ss = [];
for i=1:rgnnum
   ss(i) = r(i).Gravity(1);
end;

[ssnew, ssidx] = sort(ss,'ascend');


segres = uint16(segres);
segres(:) = 0;

for i=1:rgnnum % regions with size NaN is sorted to the end  
    segres(rgn(ssidx(i)).PixelIdxList) = i;
end;

%-----------------------------------
% test the uniqueness of the labels
%-----------------------------------

fprintf('Checking uniqueness of labels...\n');

tt=segres;
ss = regionprops(segres,'PixelIdxList','Area');
iii = find([ss.Area]>0);
num = length(iii);

rgnMultipleLabels = [];

for i=1:num
    tt(:)= 0;
    tt(ss(iii(i)).PixelIdxList) = 1;
    tt = bwlabeln(tt);
    if max(tt(:))>1
        rgnMultipleLabels = [rgnMultipleLabels,iii(i)];
    end;
    
end;

%rgnMultipleLabels

save(outimgname, 'head_segImg2', 'head_rgnSeg', 'tail_rgnSeg', 'tail_segImg2', 'trunk_segImg2', 'trunk_rgnSeg', 'segres', 'rgnMultipleLabels');

return;

