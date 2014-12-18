function [myord] = corelinegraph(d)
%%function [myord] = corelinegraph(d)
%
% find the core line graph from a MST constructed from the distance matrix d
%
% Copyright Hanchuan peng
%20050304

N = size(d,1);

m = mst(d);
m2 = m+m';

xx = getallpairdist(m2.*d);
tmp = find(xx==max(xx(:)));
[nodeStart,nodeEnd]=ind2sub([N N],tmp(1));

mytree = bfs_1root(m2, nodeStart);


myord = zeros(N,1); 
myord(1) = nodeEnd;
i=2;
while 1,
  myord(i) = mytree(myord(i-1),3);
  if myord(i)==nodeStart,
     break;
  end;
  i=i+1;
end;
Lmax = i;
myord = myord(1:Lmax);

return;



%%%============================
function d = getallpairdist(m2)
N = length(m2);
d = zeros(N,N);
 
T = uint8(full(~~m2));
 
for i=1:N,
    nodeStart = i;
    mytree = bfs_1root(T, nodeStart);
 
 
    for j=1:N,
        if j==i,
            d(i,j)=0;
            continue;
        end;
         
        nodeEnd = j;
         
        myord = zeros(N,1);
        myord(1) = nodeEnd;
        k=2;
        d(i,j)=0;
        while 1,
            myord(k) = mytree(myord(k-1),3);
            if myord(k)==nodeStart,
                break;
            end;
            d(i,j) = d(i,j)+m2(myord(k-1), myord(k));
            k=k+1;
        end;
    end;
end;
return;


