function d = posdistmatrix(pos)
% Copyright Hanchuan Peng

NU = length(pos);
d = zeros(NU, NU);
for i=1:NU,
    for j=i:NU,
        d(i,j) = sqrt((pos(i).x  - pos(j).x).^2 + (pos(i).y  - pos(j).y).^2);
    end;
end;
d=d+d'; 
d = d./max(d(:));