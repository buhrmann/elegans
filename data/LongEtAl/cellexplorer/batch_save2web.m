function batch_save2web(img_gray, img_objMask, targetdir, img_color, cellname)
%function batch_save2web(img_gray, img_objMask, targetdir, img_color, cellname)
%
% Generate the files that are needed in annotation of a worm
%
% by Hanchuan Peng

fprintf('Generating initial cell annotation file for VANO ...');

if targetdir(end)~='/',
    targetdir = [targetdir '/'];
end;

if ~exist(targetdir, 'dir'), 
    mkdir(targetdir);
end;

NDepth = size(img_gray,3);
r = struct(measure(img_objMask,  img_gray, {'center', 'gravity', 'Mean', 'Stddev', 'Size'}));
for i=1:length(r), 
    t(i,:)=[r(i).Gravity(1) r(i).Gravity(2) r(i).Gravity(3) r(i).id r(i).Mean r(i).StdDev r(i).Size];
    t(i,1:3) = round(t(i,1:3));
    
    if nargin<5,
        cellname{i}='';
    end;
end;


%%%========== sort the cell using the x coordinates (from left to right)
NCOL = size(t,2)+1;

[tmp, II] = sort(t(:,1));
for i=1:size(t,1),
    t(i,NCOL) = find(II==i); % find the sorted index number
end;

%%============ genarate an initial cell annotation file
fid = fopen([targetdir 'ano.ini'], 'wt');
RR = 5;
siz = size(img_gray);
for i=1:size(t,1),
    j = II(i);
    tmpv = img_gray(find(img_objMask==t(j,4)));
    mean_tmpv = mean(tmpv(:));
    peak_tmpv = max(tmpv(:));
    
    fprintf(fid, '%d,%d,%s,,%d,%d,%d,%5.3f,%5.3f,%5.3f,%5.3f,%5.3f\n', ...
        j, t(j,NCOL), cellname{j}, round(t(j,3)), round(t(j,1)), round(t(j,2)), peak_tmpv, mean_tmpv, t(j,6), t(j,7), round(t(j,7)*mean_tmpv)); % generate csv file, Apr.30, 2006

end;
fclose(fid);
