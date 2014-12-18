function [rgM, rgMStacks] = compute_APDVLRgraph(annoCellnum, Pos) 
% function [rgM, rgMStacks] = compute_APDVLRgraph(annoCellnum, Pos) 
% 
% annoCellnum: number of annotated cells, e.g., 357 
% trainingStackIdx: index of training stacks
% Pos: x,y,z position matrix of cells, annoCellnum*3*(num of stacks), note that
%
%
% F. Long
% 20080819

stacknum = size(Pos,3);

rgM = zeros(annoCellnum,annoCellnum,3); % binary APDVLR adjacency matrix
rgMStacks = zeros(annoCellnum,annoCellnum,stacknum, 3);

dataM = zeros(stacknum, annoCellnum, 3);
dataM = permute(Pos, [3 1 2]);

ff = squeeze(sum(Pos,2)~=0);

pp = sum(ff,2)'; % pp records in how many stacks each cell has been annotated

stackDiffNum = 0;


for k=1:3

    t=zeros(annoCellnum);

    for i=1:stacknum, 

        II0 = find(ff(:,i)~=0); % find those cells detected       

        [v, YY]=sort(dataM(i,II0,k)); 
        II=II0(YY); 

        for j=1:length(II),
            rgMStacks(II(1:j-1),II(j), i, k) = 1;
        end;

        % deal with equal values, assign no AP/DV/LR relationship if equal
        % value

        val = unique(v);

        for j=1:length(val)
            ind = find(v==val(j));
            if length(ind)>1
                rgMStacks(II0(YY(ind)),II0(YY(ind)), i, k) = 0;
            end;
        end;


    end;

    t = sum(rgMStacks(:,:,:,k),3);    

    for i=1:annoCellnum, 
        for j=1:annoCellnum, 
            if (t(i,j)>=(min([pp(i), pp(j)])-stackDiffNum)), 
                rgM(i,j,k)=1; 
            end; 
        end; 
    end;
end;