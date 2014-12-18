function [transImg, transPts, T, xdata, ydata, zdata] = affineTransImg3D(targetImg, subjectImg, targetCpt, subjectCpt, subjectPts, displayTag, warpimgTag)
% function [transImg, transPts, T, xdata, ydata, zdata] = affineTransImg3D(targetImg, subjectImg, targetCpt, subjectCpt, subjectPts, displayTag,warpimgTag)
%
% 
% Register a subject image into a target image using 3D affine transform.
% The transform is derived from the pair-wise control points in subject and
% test images. The image can be 3D or 2D
% 
% parameters:
%
% targetImg: target image
% subjectImg: subject image
% targetCpt: control points of the target image, is the number of
%            control points. Each row is the x, y, z, ...
% subjectCpt: control points of the subject image
% subjectPts: points that are particularly interested in subject image
% displayTag: if 1 then display the overlay of transformed image and the
%             target image, otherwise no display
% transImg: transformed image
% transPts: transformed point array of subjectPts
% T: the affine transformation derived from the controling points
% xdata, ydata, zdata: see imtransform3D.m. These parameters will be used
% when overlay the transformed image and the target image.
%
% F. Long
% 20071217

% ---------------------------
% derive the affine transform
% ---------------------------

transImg = [];
T = [];

if warpimgTag == 1
    dimT = ndims(targetImg);
    dimS = ndims(subjectImg);
else
    dimT = 0;
    dimS = 0;
end;


lenT = size(targetCpt,1);
lenS = size(subjectCpt,1);

if dimT~=dimS | lenT~=lenS
    return;
end;


M = size(subjectCpt,1);
X = [subjectCpt, ones(M,1)];
U = targetCpt;
K = size(targetCpt,1);

Tinv = X\U; 

len = size(Tinv,2);
Tinv(:,len+1) = [zeros(1,len) 1]';


T = inv(Tinv);
T(:,len+1) = [zeros(1,len) 1]';


tform1 = maketform('affine', T); 
tform2 = maketform('affine', Tinv); 


% ------------
% compute transPts
% ------------

[transPts(:,1), transPts(:,2), transPts(:,3)] = tformfwd(tform2, subjectPts(:,1), subjectPts(:,2), subjectPts(:,3)); % in the order of x,y,z


% ------------
% warp image
% ------------

if warpimgTag == 0
    transImg = [];
    xdata = [];
    ydata = [];
    zdata = [];
else
    
    [transImg,xdata,ydata,zdata] = imtransform3D(subjectImg, tform2, 'fillValues', 0,...
                              'xdata', [1 size(targetImg,2)],...
                              'ydata', [1 size(targetImg,1)],...
                              'zdata', [1 size(targetImg,3)]); %imtransform3D.m is revised from imtransform.m. It extends the spatial transform from 2D to 3D
end;


if displayTag == 1
    
    szTrans = size(transImg);
    szTarget = size(targetImg);
    
    szTrans = szTrans(1:3);
    szTarget = szTarget(1:3);
    
    xyz = round(abs([xdata(1), ydata(1), zdata(1)]));


    if xdata(1)<0 % targetImg_ch shift rightward
        xrange_trans = [1,szTrans(2)];
        xrange_target = [1+xyz(1),szTarget(2)+xyz(1)];
    else %transImg_ch shift rightward
        xrange_trans = [1+xyz(1),szTrans(2)+xyz(1)];
        xrange_target = [1, szTarget(2)]; 
        
    end;
            
    if ydata(1)<0 % targetImg_ch shift rightward
        yrange_trans = [1,szTrans(1)];
        yrange_target = [1+xyz(2),szTarget(1)+xyz(2)];
    else %transImg_ch shift rightward
        yrange_trans = [1+xyz(2),szTrans(1)+xyz(2)];
        yrange_target = [1, szTarget(1)]; 
        
    end;


    if zdata(1)<0 % targetImg_ch shift rightward
        zrange_trans = [1,szTrans(3)];
        zrange_target = [1+xyz(3),szTarget(3)+xyz(3)];
    else %transImg_ch shift rightward
        zrange_trans = [1+xyz(3),szTrans(3)+xyz(3)];
        zrange_target = [1, szTarget(3)]; 

    end;


    
    
    sznew = [max(yrange_trans(2),yrange_target(2)), max(xrange_trans(2),xrange_target(2)), max(zrange_trans(2),zrange_target(2))];

    % overlay each channel
    for ch=1:size(transImg,4)
        
    
        transImg_ch = squeeze(transImg(:,:,:,ch));
        targetImg_ch = squeeze(targetImg(:,:,:,ch));

        transImg_chNew = zeros(sznew);
        targetImg_chNew = zeros(sznew);

        transImg_chNew(yrange_trans(1):yrange_trans(2), xrange_trans(1):xrange_trans(2), zrange_trans(1):zrange_trans(2)) = transImg_ch;
        targetImg_chNew(yrange_target(1):yrange_target(2), xrange_target(1):xrange_target(2), zrange_target(1):zrange_target(2)) = targetImg_ch;

        nn = [];
        nn(:,:,:,1) = transImg_chNew;
        nn(:,:,:,2) = targetImg_chNew;

        joinchannels('rgb',nn)
    end;

    
end;



return;