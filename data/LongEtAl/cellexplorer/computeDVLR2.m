function [DVLR, VRcenter, VLcenter, DRcenter, DLcenter] = computeDVLR2(inimg,id_dapi,id_gfp,filename)
% function [DVLR, VRcenter, VLcenter, DRcenter, DLcenter] = computeDVLR2(inimg,id_dapi,id_gfp,filename)
%
%
% F. Long
% 20071105

%---------------------------------------------------------
% compute the 2d cross view projection of GFP and DAPI channels
%----------------------------------------------------------

ap_range = [0.35, 0.8]; 
xsize = size(inimg,2);
ysize = size(inimg,1);
zsize = size(inimg,3);

xzsum_DAPI = squeeze(sum(inimg(:,round(ap_range(1)*xsize):round(ap_range(2)*xsize),:,id_dapi), 2)); %row is Y, col is Z
xzsum_GFP = squeeze(sum(inimg(:,round(ap_range(1)*xsize):round(ap_range(2)*xsize),:,id_gfp), 2));

xzsum_DAPI = xzsum_DAPI/max(xzsum_DAPI(:))*255;
xzsum_GFP = xzsum_GFP/max(xzsum_GFP(:))*255;

figure; imagesc(xzsum_DAPI);
figure; imagesc(xzsum_GFP);

% ----------------------------------------------------------------------
% first automatically detect the centers of the four blobs of projected BWM
% ----------------------------------------------------------------------

thre = graythresh(xzsum_GFP)*255;

findtag = 1;

iter = 0;
while (1)

    iter = iter + 1;
    threImg = xzsum_GFP>thre;
    bgdsegImg = bwlabel(threImg);
    blobnum =  max(bgdsegImg(:));
    
    ss = regionprops(bgdsegImg,'Area');
    
    increasetag = 0; decreasetag = 0;
    
    if max([ss.Area])>20*min([ss.Area]) 
        increasetag = 1;
    else   
        if (blobnum<4) & (thre<255)
            increasetag = 1;
        else
            if (blobnum>4) & (thre>0)
                decreasetag = 1;
            else
                if blobnum == 4
                    findtag = 1;
                    break;
                end;
            end;
        end;
    end;
    
    if increasetag == 1
        thre = thre + 10;
    end;
    
    if decreasetag == 1
        thre = thre - 10;
    end;
    
    if iter>30
        break;
    end;
end;
    
manualtag = 1;

if findtag == 1
    r = struct(measure(uint8(bgdsegImg), uint8(xzsum_GFP), {'gravity'}));
    hold on;
    for k=1:blobnum
        X(k) = round(r(k).Gravity(1));
        Y(k) = round(r(k).Gravity(2));
        plot(X(k)+1,Y(k)+1,'w.'); hold on; 
    end;
    
    ps = input('Are the detected centers satisfactory?  (y/n)','s');
    
    if strcmp(ps,'y')==1
        manualtag = 0;
    end;
    
end;


% ---------------------------------------------------------------------------
% manually locate the four blobs if automatic approach does not work well 
% ---------------------------------------------------------------------------


if manualtag ==1

    
    fprintf('OK, automated detection of the blob centers is unsatisfactory. Please move the cursor and click at the center positions of four brightest blobs ...\n');
    
    figure; imagesc(xzsum_GFP);
    [X Y] =ginput;

    hold on; 
    plot(X,Y,'k.')

    X = X-1; Y = Y-1; 

end;

for i=1:length(X)
    r(i).Centroid = [X(i) Y(i)];
end;


% ----------------------------------------------------
% find approriate pair-wise blobs and cutting planes
% ----------------------------------------------------

i=2;
stopFlag = 0;
while ((i<4)&(stopFlag==0))
    slope = (r(i).Centroid(2)-r(1).Centroid(2))/(r(i).Centroid(1)-r(1).Centroid(1));
    candpt = setdiff([1 2 3 4], [1 i]);
    y1 =  slope*(r(candpt(1)).Centroid(1)-r(1).Centroid(1))+r(1).Centroid(2);
    y2 =  slope*(r(candpt(2)).Centroid(1)-r(1).Centroid(1))+r(1).Centroid(2);
    if (r(candpt(1)).Centroid(2)-y1)*(r(candpt(2)).Centroid(2)-y2)<0
        stopFlag = 1;
    else
        i = i+1;
    end;
end;

% two pairs of blobs and two cutting planes
candpt = setdiff([1 2 3 4], [1 i]);

pt1_1 = (r(1).Centroid + r(candpt(1)).Centroid)/2;
pair2nd = setdiff([1 2 3 4],[1 candpt(1)]);
pt1_2 = (r(pair2nd(1)).Centroid + r(pair2nd(2)).Centroid)/2;


pt2_1 = (r(1).Centroid + r(candpt(2)).Centroid)/2;
pair2nd = setdiff([1 2 3 4],[1 candpt(2)]);
pt2_2 = (r(pair2nd(1)).Centroid + r(pair2nd(2)).Centroid)/2;

% find appropriate cutting plane 
slope1 = (pt1_1(2)-pt1_2(2))/(pt1_1(1)-pt1_2(1));
slope2 = (pt2_1(2)-pt2_2(2))/(pt2_1(1)-pt2_2(1));

[slope1, slope2];

slope = slope1; 
pt_1 = pt1_1;
pt_2 = pt1_2;

yy = [1:size(xzsum_GFP,1)];

if (abs(slope)==Inf)
    DV1(:,1:pt_1(1)) = 0;
    DV1(:,pt_1(1)+1:size(DV1,2)) = 1;
else
    for i=1:size(xzsum_GFP,2)
        y =  slope*(i-pt_1(1))+pt_1(2);
        tmp = find(yy<=y);
        DV1(tmp, i) = 1;
        DV1(setdiff(yy,tmp),i) = 0;
    end;
end;

peakval = (xzsum_DAPI>220);
[y2, x2] = find(peakval>0);

if (abs(slope)==Inf)
    x1 = repmat(pt_1(1),[length(x2),1]);
    y1 = y2;
else
    x1 = (slope*slope*pt_1(1)-slope*pt_1(2)+slope*y2+x2)/(slope*slope+1);
    y1 = slope*(x1-pt_1(1))+pt_1(2);
end;
sum1 = sum(sqrt((x2-x1).^2+(y2-y1).^2));


slope = slope2; 
pt_1 = pt2_1;
pt_2 = pt2_2;

if (abs(slope)==Inf)
    DV2(:,1:pt_1(1)) = 0;
    DV2(:,pt_1(1)+1:size(DV1,2)) = 1;

else
    for i=1:size(xzsum_GFP,2)
        y =  slope*(i-pt_1(1))+pt_1(2);
        tmp = find(yy<=y);
        DV2(tmp, i) = 1;
        DV2(setdiff(yy,tmp),i) = 0;
    end;    
end;

if (abs(slope)==Inf)
    x1 = repmat(pt_1(1),[length(x2),1]);
    y1 = y2;
else
    x1 = (slope*slope*pt_1(1)-slope*pt_1(2)+slope*y2+x2)/(slope*slope+1);
    y1 = slope*(x1-pt_1(1))+pt_1(2);
end;
sum2 = sum(sqrt((x2-x1).^2+(y2-y1).^2));

% -------------------------------------
% identify ventral/dorsal, left/right
% -------------------------------------

if (sum1>sum2) 
    tmp = DV1;
    DV1 = DV2;
    DV2 = tmp;
end;

if (sum(sum(peakval.*~DV2))<sum(sum(peakval.*DV2))) 
    DV2 = ~DV2;
end;

DV = DV1+DV2*2; % the four quadrants are coded: VL:0;VR:1:DL:2; DR:3

% determine in DV1 which side is right (coded in 1), which side is left ( coded in 0)

n0 = (pt_1+pt_2)/2;

code = DV(sub2ind(size(xzsum_DAPI), round(Y),round(X)));

n1 = round([X(find(code==0)), Y(find(code==0))]); % ventral side code are 0,1
n2 = round([X(find(code==1)), Y(find(code==1))]);

k1 = (n1(2)-n0(2))/(n1(1)-n0(1));
k2 = (n2(2)-n0(2))/(n2(1)-n0(1));
angle = atan((k2-k1)/(1+k2*k1));

if (angle <0) % n2 to n1 clock wise rotation, switch left/right in DV1
    DV1 = ~DV1;
end;


DVLR = DV1+DV2*2; % the four quadrants are coded: VL:0;VR:1:DL:2; DR:3
figure; imagesc(DVLR);


% ------------------------------------------------------------------------------------
% assign the center of each bright blob to one of the four quadrants: VR, VL, DR, DL
% ------------------------------------------------------------------------------------

for i=1:4
    val = DVLR(round(r(i).Centroid(2)), round(r(i).Centroid(1)));
    switch val
        case 0
            VLcenter = r(i).Centroid; % row is Y, col is Z of the original 3D image stack
        case 1
            VRcenter = r(i).Centroid;            
        case 2
            DLcenter = r(i).Centroid;            
        case 3
            DRcenter = r(i).Centroid;                        
            
    end;
end;


return;



