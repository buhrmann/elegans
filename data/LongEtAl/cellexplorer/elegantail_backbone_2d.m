function [newpos] = elegantail_backbone_2d(inimg2d)
%function [newpos] = elegantail_backbone_2d(inimg2d)
%
% Find some knots of the "backbone" of the tail
%
% Copyright Hanchuan Peng

inimg2d = findMaxSzObj(uint8(inimg2d));

sz = size(inimg2d);

%% ==== 

ept = findedgept(inimg2d); 
ept = smooth_object_contour(ept, 20, 20); 

figure;hold on;
plot(ept.y, ept.x, 'b.');axis image; hold on

%% ====

inimg2d = floodUsingEdgePt(inimg2d, ept); 
ept = findedgept(inimg2d); 

pos = getposusingx(inimg2d, 15);
pos = [pos, getposusingy(inimg2d, 15)];

myord = corelinegraph(posdistmatrix(pos));
pos = pos(myord);

sxx = [pos(:).x];
syy = [pos(:).y];


figure;
imagesc(inimg2d); hold on; plot(syy, sxx, '*'); axis image;

%% ====

[edge1pt, edge2pt] = initialOppositeEdge(ept, pos, sz(1:2));

plot(edge1pt(:,2), edge1pt(:,1), 'g.');
plot(edge2pt(:,2), edge2pt(:,1), 'y.');

%% ====

k=0;
for i=2:length(pos)-1,
    [tmppos, MinD1, MinD2] = adjustpos(pos(i), edge1pt, edge2pt);
    if (i>1 & i<length(pos) & MinD1<=1 & MinD2<=1),
        continue; 
    else,
        k=k+1;
        newpos(k) = tmppos;
    end;
end;

[MinD1, MinDpt11] = mindistptonedge(newpos(1), edge1pt);
[MinD2, MinDpt12] = mindistptonedge(newpos(1), edge2pt);

[MinD1, MinDpt21] = mindistptonedge(newpos(end), edge1pt);
[MinD2, MinDpt22] = mindistptonedge(newpos(end), edge2pt);

[edge1pt, edge2pt] = refineOppositeEdge(ept, MinDpt11, MinDpt12, MinDpt21, MinDpt22);
plot(edge1pt(:,2), edge1pt(:,1), 'g.');
plot(edge2pt(:,2), edge2pt(:,1), 'y.');

tmppos.x = edge1pt(1,1);
tmppos.y = edge1pt(1,2);
newpos = [tmppos, newpos];

tmppos.x = edge1pt(end,1);
tmppos.y = edge1pt(end,2);
newpos = [newpos, tmppos];

%% ====
pos = newpos;
clear newpos;

totallen = 0;
for i=1:length(pos)-1,
    totallen = totallen + disttwopt(pos(i), pos(i+1));
end;

NMin = 20;
LMin = totallen/NMin;

k=0;
for i=1:length(pos),
    if i==1 | i==length(pos),
        k=k+1;
        newpos(k) = pos(i);
        continue;
    end;
    
    if disttwopt(pos(i), newpos(k))>=LMin,
        k=k+1;
        newpos(k) = pos(i);
    end;
end;

%% ====

pos = newpos;
k=0;
for i=1:length(pos)-1,
    k=k+1;
    newpos(k) = pos(i);
    k=k+1;
    newpos(k).x = (pos(i).x+pos(i+1).x)/2;
    newpos(k).y = (pos(i).y+pos(i+1).y)/2;
end;
k=k+1;
newpos(k) = pos(end);
pos = newpos;

%% ====

for i=1:length(pos),
    [newpos(i), MinD1, MinD2] = adjustpos(pos(i), edge1pt, edge2pt);

end;

plot([newpos(:).y], [newpos(:).x], 'r-o'); axis image; hold on;

return;



%%=====================================
function outimg2d = findMaxSzObj(inimg2d, b_modelbg)
if nargin<2,
    b_modelbg=0;
end;

if b_modelbg==1,
    outimg2d = uint8(double(~inimg2d)+0);
else,
    outimg2d = inimg2d;
end;
%
L = label(outimg2d);
Lsz = measure(L, outimg2d, {'size'});    
[mii, Lii] = max(Lsz.Size);
outimg2d = uint8(L==Lii);

if b_modelbg==1,
    outimg2d = ~outimg2d;
end;

return;



%%=====================================
function [edge1pt, edge2pt] = refineOppositeEdge(ept, MinDpt11, MinDpt12, MinDpt21, MinDpt22)
% function [edge1pt, edge2pt] = refineOppositeEdge(ept, MinDpt11, MinDpt12, MinDpt21, MinDpt22)
% Copyright Hanchuan Peng

N = length(ept.x);


edge1pt=[]; 
edge2pt=[]; 

i0 = find(ept.x==MinDpt11.x & ept.y==MinDpt11.y);
i1 = find(ept.x==MinDpt12.x & ept.y==MinDpt12.y);

if (abs(i1-i0)<N/2),
        tmpind = round((i0+i1)/2);
        bkpt1.x = ept.x(tmpind);
        bkpt1.y = ept.y(tmpind);
else,
        tmpind = mod(round((i0+i1+N)/2), N);
        if (tmpind==0) tmpind=N; end; 
        bkpt1.x = ept.x(tmpind);
        bkpt1.y = ept.y(tmpind);
end;

i0 = find(ept.x==MinDpt21.x & ept.y==MinDpt21.y);
i1 = find(ept.x==MinDpt22.x & ept.y==MinDpt22.y);

if (abs(i1-i0)<N/2),
       tmpind = round((i0+i1)/2);
        bkpt2.x = ept.x(tmpind);
        bkpt2.y = ept.y(tmpind);
else,
        tmpind = mod(round((i0+i1+N)/2), N);
        if (tmpind==0) tmpind=N; end; 
        bkpt2.x = ept.x(tmpind);
        bkpt2.y = ept.y(tmpind);
end;

indpt1 = find(ept.x==bkpt1.x & ept.y==bkpt1.y);
indpt2 = find(ept.x==bkpt2.x & ept.y==bkpt2.y);

if indpt1<indpt2, %%they should never equal each other
    edge1pt = [ept.x(indpt1:indpt2-1), ept.y(indpt1:indpt2-1)];
    edge2pt = [ept.x([indpt2:end, 1:indpt1-1]), ept.y([indpt2:end, 1:indpt1-1])];
elseif indpt1>indpt2,
    edge1pt = [ept.x([indpt1:end, 1:indpt2-1]), ept.y([indpt1:end, 1:indpt2-1])];
    edge2pt = [ept.x([indpt2:indpt1-1]), ept.y([indpt2:indpt1-1])];
end;

return;


%%=====================================
function [edge1pt, edge2pt] = initialOppositeEdge(ept, bpt, imgsz)
%function [edge1pt, edge2pt] = initialOppositeEdge(ept, bpt, imgsz)
% ept -- the set of all edge points
% bpt -- the set of backbone points
% Copyright Hanchuan Peng

ptlist = [ept.x(:) ept.y(:)];
ptlistind = sub2ind(imgsz, ptlist(:,1), ptlist(:,2));

[segpt1d, segpt1] = mindistptonedge(bpt(1), ptlist);
indpt1 = intersect(find(ept.x==segpt1.x), find(ept.y==segpt1.y));

[segpt2d, segpt2] = mindistptonedge(bpt(end), ptlist);
indpt2 = intersect(find(ept.x==segpt2.x), find(ept.y==segpt2.y));

if indpt1<indpt2, 
	edge1pt = ptlist([indpt1:indpt2-1], :);
	edge2pt = ptlist([indpt2:end, 1:indpt1-1], :);
elseif indpt1>indpt2,
	edge1pt = ptlist([indpt1:end, 1:indpt2-1], :);
	edge2pt = ptlist([indpt2:indpt1-1], :);
end;
    
return;

%% ===================================
function ept = findedgept(inimg2d)

% Copyright Hanchuan Peng

b_useMatlabCode = 1; 
if b_useMatlabCode,

    tmp_ept = bwboundaries(inimg2d); 
    for i=1:length(tmp_ept),
        tmp_len(i)=size(tmp_ept{i}, 1);
    end;
    [tmp, ii]=max(tmp_len);
    ept.x = tmp_ept{ii}(1:end-1,1);
    ept.y = tmp_ept{ii}(1:end-1,2);

else, 

    sz = size(inimg2d);
    tmpimg = zeros(sz+4);
    tmpimg(3:sz(1)+2, 3:sz(2)+2) = inimg2d;

    lut = makelut('sum(x(:)) < 9 & x(5)==1', 3);
    e = double(applylut(~~tmpimg,lut));

    while 1,
      lut = makelut('sum(x([2 4 6 8])) <= 1 & x(5)==1', 3);
      e1 = double(applylut(e,lut));
      if isempty(find(e1)),
          break;
      end;
      e = e-e1;
    end;

    bw = bwlabel(e);
    M = max(bw(:));

    if M~=1,
        fprintf('The number of closed region should be 1. But find %d rgns. Go to manual check!\n', M);
        keyboard;
    end;

    [ept.x, ept.y] = find(bw==1);
    ept.x = ept.x-2; 
    ept.y = ept.y-2;

    tmpimg=zeros(sz);
    for i=1:length(ept.x), 
        tmpimg(ept.x(i), ept.y(i))=1; 
    end;
    p = curveWalk(tmpimg, [ept.x(1) ept.y(1)]);
    [ept.x, ept.y] = ind2sub(sz, p);

end;

return;

            
%%==========================================================

function pos = getposusingx(inimg2d, KK)
% Copyright Hanchuan Peng

sz = size(inimg2d);
if nargin<2,
  KK=20;
end;

blkx = [1:round(sz(1)/KK):sz(1)];
blky = [1:round(sz(2)/KK):sz(2)];

if sz(1)-blkx(end)<round(sz(1)/KK)/2, blkx(end)=sz(1);else,blkx = [blkx sz(1)];end;
blkx(1) = 0;

if sz(2)-blky(end)<round(sz(2)/KK)/2, blky(end)=sz(2);else,blky = [blky sz(2)];end;
blky(1) = 0;

nblkx = length(blkx)-1;
nblky = length(blky)-1;

k=0;
for i=1:nblkx,
    curblk = inimg2d(blkx(i)+1:blkx(i+1), :);
    curlabel = bwlabel(curblk);
    ncurrgn =  max(curlabel(:));
    for j=1:ncurrgn,
        k=k+1;
        curind = find(curlabel==j);
        [xxtmp, yytmp] = ind2sub(size(curblk), curind);
        pos(k).x = blkx(i) + mean(xxtmp);
        pos(k).y = mean(yytmp);
    end;
end;

%%====================================================

function pos = getposusingy(inimg2d, KK)
% Copyright Hanchuan Peng

sz = size(inimg2d);
if nargin<2,
  KK=20;
end;

blkx = [1:round(sz(1)/KK):sz(1)];
blky = [1:round(sz(2)/KK):sz(2)];

if sz(1)-blkx(end)<round(sz(1)/KK)/2, blkx(end)=sz(1);else,blkx = [blkx sz(1)];end;
blkx(1) = 0;

if sz(2)-blky(end)<round(sz(2)/KK)/2, blky(end)=sz(2);else,blky = [blky sz(2)];end;
blky(1) = 0;

nblkx = length(blkx)-1;
nblky = length(blky)-1;

k=0;
for i=1:nblky,
    curblk = inimg2d(:, blky(i)+1:blky(i+1));
    curlabel = bwlabel(curblk);
    ncurrgn =  max(curlabel(:));
    for j=1:ncurrgn,
        k=k+1;
        curind = find(curlabel==j);
        [xxtmp, yytmp] = ind2sub(size(curblk), curind);
        pos(k).x = mean(xxtmp);
        pos(k).y = blky(i) + mean(yytmp);
    end;
end;


%%======================== 
% function d = posdistmatrix(pos)
% % Copyright Hanchuan Peng
% 
% NU = length(pos);
% d = zeros(NU, NU);
% for i=1:NU,
%     for j=i:NU,
%         d(i,j) = sqrt((pos(i).x  - pos(j).x).^2 + (pos(i).y  - pos(j).y).^2);
%     end;
% end;
% d=d+d'; 
% d = d./max(d(:));


%%======================================
function [newpos, MinD1, MinD2] = adjustpos(curpos, edge1pt, edge2pt)
% Copyright Hanchuan Peng

oldpos = curpos;

curpos.x = round(curpos.x);
curpos.y = round(curpos.y);

TH = 2;
lastdiff = 10000;
newpos = curpos;

k=0;
while k<10,
    k=k+1;
    
    [MinD1, MinDpt1] = mindistptonedge(newpos, edge1pt);
    [MinD2, MinDpt2] = mindistptonedge(newpos, edge2pt);
    
    curdiff = abs(MinD1-MinD2);        

    if curdiff<TH,
        break; 
    end;

    if curdiff>=lastdiff,
        newpos = curpos;
        break; 
    end;

    lastdiff = curdiff;
    curpos = newpos;

    newpos.x = round(0.5*(MinDpt1.x + MinDpt2.x));
    newpos.y = round(0.5*(MinDpt1.y + MinDpt2.y));
end;

plot(newpos.y, newpos.x, 'ro');
plot(oldpos.y, oldpos.x, 'r>');

return;


%%======================================
function [MinD, MinDpt] = mindistptonedge(curpos, ptlist)
% Copyright Hanchuan Peng

N = length(ptlist);
d = (curpos.x - ptlist(:,1)).^2 + (curpos.y - ptlist(:,2)).^2;
[MinD, ind] = min(d);
MinDpt.x = ptlist(ind,1);
MinDpt.y = ptlist(ind,2);
return;

%%======================================
function [D] = disttwopt(p1, p2)
% Copyright Hanchuan Peng

if isa(p1, 'struct')==0,
    np1.x = p1(1);
    np1.y = p1(2);
else,
    np1=p1;
end;

if isa(p2, 'struct')==0,
    np2.x = p2(1);
    np2.y = p2(2);
else,
    np2=p2;
end;

D = sqrt((np1.x-np2.x).^2 + (np1.y-np2.y).^2);
return;
