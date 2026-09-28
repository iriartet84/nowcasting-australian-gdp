clear; clc; close all;

% 1. Load data
cd('/MATLAB Drive/Nowcasting_project/');

dataFile = 'PCAdata.xlsx';

if ~isfile(dataFile)
    error('Cannot open file: %s\nMake sure the file is in the MATLAB path.', dataFile);
end

varNames = {
    'IP Index, Standardized, SA, Index, 2010=100'   
    'Dwelling units approved (SA)'                   
    'New motor vehicle sales'                      
    'Total Exports: Commodities for Australia'      
    'Employed persons'                          
    'Stock index'                               
    'Exchange rate'                             
    'Unemployment rate'                           
    'Global price of Iron Ore'                   
    'Commodity prices - A$'                        
    'Composite leading indicators'                 
    'Business confidence index (BCI)'              
    'Composite Consumer Confidence'                  
    'Dr. Copper'                                
    'Coal, Australian'                            
};
nVars = numel(varNames);

opts = detectImportOptions(dataFile, 'Sheet', 'Monthlydata2');
opts.DataRange          = 'A3';   % start reading from row 3 (skip header + source row)
opts.VariableNamesRange = '';

rawTable = readtable(dataFile, opts);

dateCol   = rawTable{:, 1};
rawValues = rawTable{:, 2:(nVars+1)};

nObs       = size(rawValues, 1);
dates_full = NaT(nObs, 1);          % full-length date vector, before any row-dropping
rawData    = NaN(nObs, nVars);

for i = 1:nObs
    d = dateCol(i);
    if iscell(d), d = d{1}; end
    if ischar(d) || isStringScalar(d)
        dates_full(i) = datetime(string(d), 'InputFormat', 'yyyy-MM-dd');
    elseif isdatetime(d)
        dates_full(i) = d;
    elseif isnumeric(d) && ~isnan(d)
        dates_full(i) = datetime(d, 'ConvertFrom', 'excel');
    end

    for j = 1:nVars
        v = rawValues(i, j);
        if iscell(v), v = v{1}; end
        if isnumeric(v)
            rawData(i, j) = v;
        else
            rawData(i, j) = str2double(string(v));
        end
    end
end

fprintf('Loaded %d observations, %d variables.\n', nObs, nVars);

% 2. Clean missing-values
MISSING_SENTINEL = 99999.00;
rawData(rawData == MISSING_SENTINEL) = NaN;

rawData_base = rawData;   % keep an untouched copy: Spec B builds its
                            % transformed series from this, not from any
                            % differenced/standardized version.

% 3. ADF unit-root tests on raw levels
validRows_raw = all(~isnan(rawData_base), 2);
X_raw         = rawData_base(validRows_raw, :);

maxDiff       = 2;
intOrders_raw = NaN(nVars, 1);

fprintf('\n=== ADF Unit Root Tests - RAW levels (no differencing applied) ===\n');
fprintf('%-55s  %6s  %6s  %6s  %8s\n', 'Variable','I(0)?','I(1)?','I(2)?','Order');
fprintf('%s\n', repmat('-',1,82));

for j = 1:nVars
    series      = X_raw(:, j);
    order       = NaN;
    results_raw = NaN(1, maxDiff+1);

    for d = 0:maxDiff
        if d == 0, y = series; else, y = diff(series, d); end
        y = y(~isnan(y));
        [h, ~] = adftest(y, 'Model','ARD', 'Lags', floor(4*(length(y)/100)^(2/9)));
        results_raw(d+1) = h;
        if h && isnan(order), order = d; end
    end

    if isnan(order), order = maxDiff + 1; end   % could not reject unit root at any d tested
    intOrders_raw(j) = order;

    fprintf('%-55s  %6s  %6s  %6s  %8s\n', varNames{j}, ...
        yesno(results_raw(1)), yesno(results_raw(2)), yesno(results_raw(3)), ...
        sprintf('I(%d)', order));
end

% 4. Build the Spec B transformation
canLog = false(1, nVars);
for j = 1:nVars
    col = rawData_base(:, j);
    canLog(j) = all(col(~isnan(col)) > 0);
end

needsDiff = (intOrders_raw >= 1);

forceDiffSpecB     = {'Dwelling units approved (SA)', ...
                       'Business confidence index (BCI)', ...
                       'Composite Consumer Confidence'};
forceDiffIdx_specB = find(ismember(varNames, forceDiffSpecB));
if numel(forceDiffIdx_specB) ~= numel(forceDiffSpecB)
    error('forceDiffSpecB: could not match all names to varNames - check spelling.');
end
needsDiff(forceDiffIdx_specB) = true;

fprintf('\n=== Transformation plan (driven by ADF intOrders_raw) ===\n');
fprintf('%-50s  %-8s  %-6s  %s\n','Variable','Order','CanLog','Spec B transform');
fprintf('%s\n', repmat('-',1,80));
for j = 1:nVars
    if needsDiff(j)
        tx = ternary(canLog(j), 'Delta log(x)', 'Delta x');
    else
        tx = ternary(canLog(j), 'log(x)',  'x (level)');
    end
    fprintf('%-50s  I(%d)      %-6s  %s\n', varNames{j}, intOrders_raw(j), ...
        ternary(canLog(j),'yes','no'), tx);
end

% 5. Apply the Spec B transformation
rawData_logD = rawData_base;

fprintf('\n[SPEC B] Applying transformations:\n');
for j = 1:nVars
    col = rawData_base(:, j);
    if needsDiff(j)
        if canLog(j)
            rawData_logD(:, j) = [NaN; diff(log(col))];
            fprintf('  %-50s  Delta log\n', varNames{j});
        else
            rawData_logD(:, j) = [NaN; diff(col)];
            fprintf('  %-50s  Delta  (canLog=false)\n', varNames{j});
        end
    else
        if canLog(j)
            rawData_logD(:, j) = log(col);
            fprintf('  %-50s  log-level  [I(0)]\n', varNames{j});
        else
            fprintf('  %-50s  level  [I(0), canLog=false]\n', varNames{j});
        end
    end
end

validRows_logD = all(~isnan(rawData_logD), 2);
X_logD         = rawData_logD(validRows_logD, :);
dates_logD     = dates_full(validRows_logD);
fprintf('\n[SPEC B] %d complete observations.\n', size(X_logD,1));

% 6. Run PCA on the Spec B transformed data
[coeff_logD, score_logD, latent_logD, ~, explained_logD] = ...
    pca(zscore(X_logD), 'Rows','complete');
nFactors_logD = size(coeff_logD, 2);

fprintf('\n=== [SPEC B] Log-Difference PCA - Variance Explained ===\n');
fprintf('%-6s  %-12s  %-18s\n','PC','Eigenvalue','Variance Expl. (%)');
fprintf('%s\n', repmat('-',1,40));
cumVar = 0;
for k = 1:min(nFactors_logD,10)
    cumVar = cumVar + explained_logD(k);
    fprintf('PC%-4d  %10.4f    %8.2f%%   (cum: %6.2f%%)\n', ...
        k, latent_logD(k), explained_logD(k), cumVar);
end

% 7. Sign-normalize the components
anchorVar = 'IP Index, Standardized, SA, Index, 2010=100';
anchorIdx = find(strcmp(varNames, anchorVar));

coeff_logD_signed = coeff_logD;
score_logD_signed = score_logD;

fprintf('\n[SPEC B] Sign check (anchor = %s):\n', anchorVar);
for k = 1:nFactors_logD
    thisCorr = coeff_logD(anchorIdx, k) * sqrt(latent_logD(k));
    if thisCorr < 0
        coeff_logD_signed(:,k) = -coeff_logD_signed(:,k);
        score_logD_signed(:,k) = -score_logD_signed(:,k);
        fprintf('  PC%d flipped (anchor loading was %+.3f)\n', k, thisCorr);
    else
        fprintf('  PC%d kept as-is (anchor loading was %+.3f)\n', k, thisCorr);
    end
end

tickLabels_logD = varNames;
for j = 1:nVars
    if needsDiff(j) && canLog(j),   tickLabels_logD{j} = [varNames{j} ' [Dlog]'];
    elseif needsDiff(j),            tickLabels_logD{j} = [varNames{j} ' [D]'];
    elseif canLog(j),               tickLabels_logD{j} = [varNames{j} ' [log]'];
    end
end

% 8. Correlation table for PCAs
nShow_logD   = min(4, nFactors_logD);
corrMat_logD = zeros(nVars, nShow_logD);
for k = 1:nShow_logD
    corrMat_logD(:,k) = coeff_logD_signed(:,k) * sqrt(latent_logD(k));
end

pcLabels = sprintfc('PC%d', 1:nShow_logD);

corrTable_specB = array2table(round(corrMat_logD, 4), ...
    'VariableNames', pcLabels, ...
    'RowNames', matlab.lang.makeValidName(tickLabels_logD));
corrTable_specB = addvars(corrTable_specB, tickLabels_logD(:), ...
    'Before', 1, 'NewVariableNames', 'Variable');

fprintf('\n=== [SPEC B] Correlation Table: Variables x PC1-PC4 (sign-normalized) ===\n');
disp(corrTable_specB);

writetable(corrTable_specB, 'SpecB_CorrelationTable.xlsx');
fprintf('Saved: SpecB_CorrelationTable.xlsx\n');

pc1_corr_specB = coeff_logD_signed(:,1) * sqrt(latent_logD(1));
[~, pc1_sortIdx] = sort(abs(pc1_corr_specB), 'descend');

pc1Table_specB = table(tickLabels_logD(pc1_sortIdx), ...
    round(pc1_corr_specB(pc1_sortIdx), 4), ...
    'VariableNames', {'Variable','Correlation_with_PC1'});

fprintf('\n=== [SPEC B] Variable Correlation with PC1 (ranked) ===\n');
disp(pc1Table_specB);

writetable(pc1Table_specB, 'SpecB_PC1_Correlation.xlsx');
fprintf('Saved: SpecB_PC1_Correlation.xlsx\n');

% 9. Figures
varExplTable_specB = table((1:nFactors_logD)', latent_logD, explained_logD, ...
    cumsum(explained_logD), ...
    'VariableNames', {'PC','Eigenvalue','VarianceExplained_pct','CumulativeVariance_pct'});

fprintf('\n=== [SPEC B] Variance Explained Summary ===\n');
disp(varExplTable_specB(1:min(10,nFactors_logD),:));

writetable(varExplTable_specB, 'SpecB_VarianceExplained.xlsx');
fprintf('Saved: SpecB_VarianceExplained.xlsx\n');

loadingCutoff   = 0.40;
nPCsToDescribe  = sum(cumsum(explained_logD) <= 80) + 1;
nPCsToDescribe  = min(nPCsToDescribe, nFactors_logD);

fprintf('\n=== [SPEC B] Narrative Summary of Retained Factors ===\n');
fprintf('(Components covering the leading ~80%% of variance; |loading| > %.2f shown)\n\n', loadingCutoff);

for k = 1:nPCsToDescribe
    corrCol = coeff_logD_signed(:,k) * sqrt(latent_logD(k));

    sigMask = abs(corrCol) > loadingCutoff;
    sigVars = find(sigMask);
    [~, sigOrder] = sort(abs(corrCol(sigVars)), 'descend');
    sigVars = sigVars(sigOrder);

    fprintf('PC%d - %.1f%% of variance (cumulative %.1f%%):\n', ...
        k, explained_logD(k), sum(explained_logD(1:k)));

    if isempty(sigVars)
        fprintf('  No variable exceeds |corr| > %.2f; this PC is diffuse, not anchored\n', loadingCutoff);
        fprintf('  by any single series.\n\n');
        continue;
    end

    for v = sigVars'
        sign_str = ternary(corrCol(v) > 0, '+', '-');
        fprintf('  %s %-50s  corr = %+.3f\n', sign_str, tickLabels_logD{v}, corrCol(v));
    end
    fprintf('\n');
end

fprintf('Note: signs are normalized so that "%s" loads positively on PC1.\n', anchorVar);
fprintf('Within a PC, matching signs = variables that co-move; opposite signs = inverse\n');
fprintf('relationship. The absolute sign of the PC itself remains a convention choice.\n');


% Scree plot
figure('Name','Scree Plot','Color','w','Position',[100 100 700 400]);
bar(1:nFactors_logD, explained_logD, 'FaceColor',[0.2 0.4 0.8]);
hold on;
plot(1:nFactors_logD, cumsum(explained_logD),'r-o','LineWidth',1.5,'MarkerSize',5);
yline(80,'k--','80%','LabelHorizontalAlignment','left');
xlabel('Principal Component'); ylabel('Variance Explained (%)');
title('Scree Plot');
legend('Individual','Cumulative','Location','east'); grid on;
xlim([0.5, min(nFactors_logD,12)+0.5]);

figure('Name','PC1 Loadings','Color','w','Position',[100 550 980 460]);
barh(1:nVars, coeff_logD_signed(:,1),'FaceColor',[0.2 0.4 0.8]);
set(gca,'YTick',1:nVars,'YTickLabel',tickLabels_logD,'FontSize',8);
xlabel('Loading on PC1');
title(sprintf('PC1 Loadings (sign-normalized)  (%.1f%% variance)', explained_logD(1)));
xline(0,'k-'); grid on;

subplot(1,2,1);
imagesc(corrMat_logD(:,1:2)); colormap(localRedBlueColormap()); clim([-1 1]);
set(gca,'XTick',1:2,'XTickLabel',pcLabels(1:2), ...
    'YTick',1:nVars,'YTickLabel',tickLabels_logD,'FontSize',8,'TickLength',[0 0]);
title('PC1-PC2');

subplot(1,2,2);
imagesc(corrMat_logD(:,3:4)); colormap(localRedBlueColormap()); clim([-1 1]);
set(gca,'XTick',1:2,'XTickLabel',pcLabels(3:4), ...
    'YTick',1:nVars,'YTickLabel',{},'FontSize',8,'TickLength',[0 0]);
title('PC3-PC4');

sgtitle(sprintf('Variables vs First 4 PCs (sign-normalized)  (PC1 = %.1f%% variance)', explained_logD(1)));
colorbar('Position',[0.93 0.11 0.02 0.815]);  % single shared colorbar spanning both panels

figure('Name','PC1 Over Time','Color','w','Position',[820 550 800 300]);
plot(dates_logD, score_logD_signed(:,1),'Color',[0.2 0.4 0.8],'LineWidth',1.2);
yline(0,'k--'); xlabel('Date'); ylabel('PC1 Score (std units)');
title('PC1 Factor - Log-Difference Nowcasting Index (sign-normalized)'); grid on;

% Helper functions

function cmap = localRedBlueColormap()
    % Diverging red-blue colormap for the correlation heatmap:
    % blue = negative correlation, white = zero, red = positive.
    n    = 256;
    half = n/2;
    r = [linspace(0,1,half), ones(1,half)];
    g = [linspace(0,1,half), linspace(1,0,half)];
    b = [ones(1,half), linspace(1,0,half)];
    cmap = [r(:) g(:) b(:)];
end

function s = yesno(h)
    % Converts an ADF test's binary result (h = 0 or 1) into a readable
    % 'No'/'Yes' string for the console tables.
    if h == 1, s = 'Yes'; else, s = 'No'; end
end

function s = ternary(cond, a, b)
    % Compact inline if/else, used throughout for one-line conditional
    % labeling (e.g. choosing between 'Delta log(x)' and 'log(x)' text).
    if cond, s = a; else, s = b; end
end