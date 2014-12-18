function Path = curveWalk(imgBW,p0)
%function Path = curveWalk(imgBW,p0)
%track/walk a curve from p0 (start point) and return the point series in C
% imgBW is black-white indicating curve (1) and background (0)
%
% by Hanchuan Peng
% May 2004

p0=p0(:)'; p0=p0(1:2);

imgVisit=imgBW;

k=0;
if imgBW(p0(1),p0(2))~=0,
  k=1;
  C(k,:)=p0;
  imgVisit(p0(1),p0(2))=0;
else,
  C=[];
  return;
end;

p=p0;
while 1,
  imgVisit(p(1),p(2))=0;
  [tmpFlag, MyShift]=firstIn8(extractPatch33(imgVisit, p));
  if tmpFlag==0,
    break;
  end;
 
  nextp = p + MyShift;
  p = nextp;

  k=k+1;
  C(k,:)=p;
end;

Path=sub2ind(size(imgBW),C(:,1),C(:,2));
return;

%========================
function IPatch=extractPatch33(img,p)
HEI=size(img,1);
WID=size(img,2);

x_low=max(p(1)-1,1);
x_high=min(p(1)+1,HEI);
y_low=max(p(2)-1,1);
y_high=min(p(2)+1,WID);

IPatch=zeros(3,3);

%%===revised 050308
if p(1)<=1,   I_xlow=2;  else, I_xlow=1; end;
if p(1)>=HEI, I_xhigh=2; else, I_xhigh=3; end;
if p(2)<=1,   I_ylow=2;  else, I_ylow=1; end;
if p(2)>=WID, I_yhigh=2; else, I_yhigh=3; end;

IPatch(I_xlow:I_xhigh, I_ylow:I_yhigh) = img(x_low:x_high, y_low:y_high);

%======================== 
function [PosIdx,shift]=firstIn8(x33)
%IDX=[4 7 8 9 6 3 2 1];
IDX=[4 8 6 2];
nzidx=IDX(find(x33(IDX)));
if ~isempty(nzidx),
  PosIdx=nzidx(1);
else,
  PosIdx=0;
end;
switch(PosIdx),
case 1, shift=[-1 -1];
case 2, shift=[ 0 -1];
case 3, shift=[+1 -1];
case 4, shift=[-1  0];
case 6, shift=[+1  0];
case 7, shift=[-1 +1];
case 8, shift=[ 0 +1];
case 9, shift=[+1 +1];
otherwise, shift=[];
end; 
