function [cell_corr, branch_corr, sub_corr, subcell_corr] = calculateCoTuning(frames)
%% Calculate co-tuning metrices 
% Based on O'Hare... Losonczy, Science (2022)
% Basic method: 1. Generate tuning curves for each ROI across all laps
% 2. Get pearson's correlation between ROIs
% 3. Plot in a histogram

%% Get data
cname = dir('*registered_data.mat');
cellData = importdata(cname.name);
branchData = importdata('branch_ROIs.mat');
subData = importdata('subROIs.mat');

%% Get tuning curves
% inputs: (num_envs,data,floating,plot_all, plot_oneD, plot_Location, save_flag, fname)
HPC_Analysis_Pipeline_Dendrites(1,cellData,[], 0, 0, 0, 1, '_cellData_', frames); % get curves for cell bodies and whole dendrites
HPC_Analysis_Pipeline_Dendrites(1,subData,[], 0, 0, 0, 1, '_subData_', frames); % get curves for subROIs
if ~isempty(branchData.cellMasks)
    HPC_Analysis_Pipeline_Dendrites(1,branchData,[], 0, 0, 0, 1, '_branchData_', frames); % get curves for dendritic branches
end

%% Get tuning curve files
crname = dir('*_cellData_*');
cellResp = importdata(crname.name);
sname = dir('*_subData_*');
subResp = importdata(sname.name);

%% Calculate correlation between tuning curves
% get correlation between soma and dendrites
oneD_cell_activity = cellResp.oneD_activity;
cell_corr = zeros(size(oneD_cell_activity,1)/2,1);
for cc = 1:size(oneD_cell_activity,1)/2
    resp1 = oneD_cell_activity((cc*2)-1,:)'; % soma
    resp2 = oneD_cell_activity(cc*2,:)'; % dendrite
    cell_r = corrcoef(resp1,resp2); % get pearson's r
    cell_corr(cc) = cell_r(1,2);
end

% get correlations between dendritic branches
% assumes that branches come in pairs
if ~isempty(branchData.cellMasks)
    bname = dir('*_branchData_*');
    branchResp = importdata(bname.name);
    oneD_branch_activity = branchResp.oneD_activity;
    branch_corr = zeros(ceil(size(oneD_branch_activity,1)/2),1);
    for bb = 1:size(oneD_branch_activity,1)/2
        bresp1 = oneD_branch_activity((bb*2)-1,:)'; % soma
        bresp2 = oneD_branch_activity(bb*2,:)'; % dendrite
        branch_r = corrcoef(bresp1,bresp2); % get pearson's r
        branch_corr(bb) = branch_r(1,2);
    end
    branchResp.branch_corr = branch_corr;
    save(bname.name,'branchResp')
else
    branch_corr = [];
end

% get correlations between sub-ROIs
% where each column is one subROI and each row is correlations between the
% current ROI and each other ROI in order (i.e. (1,1) is subROI 1
% correlated with subROI 2, (2,1) is 1 correlated with 3,etc. (1,2) is ROI
% 2 correlated with ROI 1, and (2,2) is ROI 2 correlated with ROI 3, etc.)
% Also, get correlations between soma and each subROI
oneD_sub_activity = subResp.oneD_activity;
removedcells = subResp.emptycells;
emptyvec = zeros(1,size(oneD_sub_activity,2));
for rr = 1:length(removedcells)
    curr_removed = removedcells(rr);
    if curr_removed == 1
        oneD_new = [emptyvec; oneD_sub_activity];
    elseif curr_removed == size(oneD_sub_activity,1)
        oneD_new = [oneD_sub_activity; emptyvec];
    else
        oneD_new = [oneD_sub_activity(1:curr_removed-1,:); emptyvec;...
            oneD_sub_activity(curr_removed:end,:)];
    end
    oneD_sub_activity = oneD_new;
end % add back in empty cells that got taken out, for proper allocated of ROIs
subROIsbyCell = subData.subROIbyCell;
cellSizes = cell2mat(cellfun(@length,subROIsbyCell,'UniformOutput',false));
sub_corr = cell(1,length(cell_corr));
subcell_corr = cell(1,length(cell_corr));
% ROI_idx = zeros(1,size(oneD_sub_activity,1));
for ii = 1:length(cell_corr) % for each cell
    % first_pos = min(find(~ROI_idx));
    % numROIs = first_pos + size(oneD_sub_activity,1) - 1;
    % ROI_idx(first_pos:numROIs) = 1;
    cresp1 = oneD_cell_activity((ii*2)-1,:)'; % soma DFF
    curr_cellSize = cellSizes(ii);
    total_cellSize = sum(cellSizes(1:ii));
    past_cells = total_cellSize - (curr_cellSize-1);
    curr_oneD_sub_activity = oneD_sub_activity(past_cells:total_cellSize,:);
    curr_oneD_sub_activity = curr_oneD_sub_activity(~all(curr_oneD_sub_activity == 0, 2),:); % get rid of empty rows
    sub_corr_single = zeros(size(curr_oneD_sub_activity,1),size(curr_oneD_sub_activity,1));
    subcell_corr_single = zeros(size(curr_oneD_sub_activity,1),1);
    for ss = 1:size(curr_oneD_sub_activity,1)
        sresp1 = curr_oneD_sub_activity(ss,:)';
        subcell_r = corrcoef(cresp1,sresp1);
        subcell_corr_single(ss,1) = subcell_r(1,2);
        for s = 1:size(curr_oneD_sub_activity,1)
            sresp2 = curr_oneD_sub_activity(s,:)';
            sub_r = corrcoef(sresp1,sresp2);
            sub_corr_single(s,ss) = sub_r(1,2);
        end
    end
    sub_corr{ii} = sub_corr_single; % save current cell's ROIs
    subcell_corr{ii} = subcell_corr_single;
end

%% Save data
cellResp.cell_corr = cell_corr;
cellResp.subcell_corr = subcell_corr;
save(crname.name,'cellResp')
subResp.sub_corr = sub_corr;
save(sname.name,'subResp')
disp('Co-tuning metrics processed and saved to processed data files')