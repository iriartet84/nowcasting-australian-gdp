%% Advanced Time Series: Nowcasting and Forecasting
% Iriarte, Lucha, Zufiria
% This code produces the results of Stock and Watson 1991
clear
clc
global yv filter n vfq capt pnk vector index ny H filterptt;          % We specify which variables are global (used in several files)
%%
%/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   Adjust any of the following to control specification desired
%+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

va=1;      % va is the vare of rnd number to fill unobseved data@
vfq=1;     % var of factor error @
% lag length of the monthly-annual series@
pphi=2;    % pphi is the max lag length
            % note: p, q1, and q2 <=pphi @
nk=pphi+1;  % nk is the first observation for which the
            % likelihood will be evaluated @
vector=[(1/3);(2/3);1;(2/3);(1/3)];
%/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%               load variables in cols
% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
%% Load variables in columns
project_path = pwd;   % Current MATLAB Drive folder
filename = fullfile(project_path, 'Final_dataset_final.xlsx');
indica = readmatrix(filename, 'Sheet', 1, 'Range', 'B2:I313');
n = size(indica,2);   % Number of variables in dataset

%% calculate the mean and std dev without counting the dummy values (99999)
gg=indica(indica(:,1)~=99999,1);
megdp=mean(gg);
stdgdp=std(gg);
gg=indica(indica(:,2)~=99999,2);
meind1=mean(gg);
stdind1=std(gg);
gg=indica(indica(:,3)~=99999,3);
meind2=mean(gg);
stdind2=std(gg);
gg=indica(indica(:,4)~=99999,4);
meind3=mean(gg);
stdind3=std(gg);
gg=indica(indica(:,5)~=99999,5);
meind4=mean(gg);
stdind4=std(gg);
gg=indica(indica(:,6)~=99999,6);
meind5=mean(gg);
stdind5=std(gg);
gg=indica(indica(:,7)~=99999,7);
meind6=mean(gg);
stdind6=std(gg);
gg=indica(indica(:,8)~=99999,8);
meind7=mean(gg);
stdind7=std(gg);

%%
%/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%           Fill unobserved and standardize
% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
indica=standard(indica);                % At this point indica is edited to the standardized values
indica2=relleno(indica,1);              % This is the EM algorithm, that fills in the dummies with random numbers
y=indica2;                              % y is the new dataset with the missing completed
ny=size(y,2);                           % Number of observed variables = 8
capt=size(y,1);                         % Number of rows
pnk=27;                                 % state: f(t+3)...f(t-4), GDP idio, monthly idios
yv=y;                                   % Just another copy of y
index=(indica~=99999);                  % 1 if observed, 0 if missing
%%
%/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%                Initial parameters' values
% +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
%In this case these are the optimal parameters so the algorithm converges quickly

startval = [
    0.599470957297903
    0.008084368475749
    0.146850652258023
    0.363902639355681
    0.853110968143140
    0.015529850859380
    0.139596531213260
    0.008699428160489
    0.175161205878894
   -0.222669365169363
    0.623120516820002
   -0.835720571606542
    0.837091578668102
   -0.156405424799253
   -0.542297524392655
   -0.232860894479314
   -0.053270728310500
   -0.455920645018056
    0.054786690682934
    0.390349249192298
    0.165972341898320
   -0.104567960282340
   -0.029414545579520
   -0.084871477984229
    1.669435592592196
   -0.750425216645459
    0.158971120508593
    0.693411706773997
    0.872729785371647
    0.649417166795388
    0.490963504551465
    0.979116238193683
    0.997859840615025
    0.196257101667040
];

nth = length(startval);  % number of parameters to be estimated
%%
%/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%         I will need the following matrices
%+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
filter=zeros(capt,pnk);          % Saved Kalman-filter estimates of the hidden state vector at each date.
%filterptt=zeros(capt,pnk,pnk);  % filterptt = optional saved uncertainty/covariance of those estimates, currently unused.

%% Maximizing the likelihood function >> same as the balanced case
options = optimset('PlotFcns',@optimplotx,'DISPLAY','iter','TolFun',1e-8, 'MaxFunEvals',2000); % Optimization settings for fminunc
                                                                                                %[x,ff]=fminunc(@ofn, startval, options);
[x,ff,EXITFLAG,OUTPUT,GRAD,HESSIAN]=fminunc(@ofn, startval);
   % x estimated parameter vector
   % ff minimized value of the objective function, i.e. negative log-likelihood
   % EXITFLAG convergence status
   % OUTPUT information about iterations/function evaluations
   % GRAD gradient at the solution
   % HESSIAN Hessian matrix at the solution

cramerrao=inv(HESSIAN);             % inverse Hessian approx variance-covariance matrix of estimates
std=sqrt(diag(cramerrao));          % square root of diagonal = standard errors
[x std]                             % Estimated parameter | standard error

forecast=zeros(8,size(filter,1));   % Creates empy matrix for fitted value, number of time periods

for i=1:size(filter,1)
    forecast(:,i)=H*filter(i,:)';   % For each date, multiply the estimated state vector by H to obtain fitted GDP and indicators
end

forecast2=forecast';                   % Transpose the forecast
gdp = forecast2(:,1)*stdgdp + megdp;   % Convert fitted GDP from standardized units back to original GDP units
                                       % The next lines convert the fitted
                                       % indicator from standardized to non
                                       % standardized
ind1=forecast2(:,2)*stdind1+meind1;   % Convert fitted indicator 1 from standardized units back to original units
ind2=forecast2(:,3)*stdind2+meind2;   % Convert fitted indicator 2 from standardized units back to original units
ind3=forecast2(:,4)*stdind3+meind3;   % Convert fitted indicator 3 from standardized units back to original units
ind4=forecast2(:,5)*stdind4+meind4;   % Convert fitted indicator 4 from standardized units back to original units
ind5=forecast2(:,6)*stdind5+meind5;   % Convert fitted indicator 5 from standardized units back to original units
ind6=forecast2(:,7)*stdind6+meind6;   % Convert fitted indicator 6 from standardized units back to original units
ind7=forecast2(:,8)*stdind7+meind7;   % Convert fitted indicator 7 from standardized units back to original units

%%
H2=H;                          % Copy the estimated measurement matrix H
H2(1,9:13)=0;                  % Remove GDP-specific idiosyncratic states

forecast=zeros(8,size(filter,1));   % Create empty matrix to store fitted values for 8 variables over all dates

for i=1:size(filter,1)
    forecast(:,i)=H2*filter(i,:)';  % Compute fitted values using the modified measurement matrix H2
end

forecast2=forecast';           % Transpose so rows are dates and columns are variables
gdp2=forecast2(:,1)*stdgdp+megdp;   % Convert the second fitted GDP series back to original GDP units
caca=[gdp gdp2];               % Put the two GDP fitted series side by side: full fitted GDP and modified fitted GDP
idx  = 1:3:size(caca,1);       % Select quarterly observation months: rows 1, 4, 7, 10, ...
sub  = caca(idx, :);           % Keep only those quarterly rows
corr(sub(:,1),sub(:,2))        % Correlation between full fitted GDP and modified fitted GDP at quarterly dates

%% Correlation between observed GDP and full fitted GDP: sanity check
raw = xlsread(fullfile(project_path, 'Final_dataset_final.xlsx'), 1, 'B2:I313');
gdp_obs = raw(:,1);             % Observed GDP from Excel
caca = [gdp_obs gdp];           % Observed GDP and full fitted GDP
idx  = find(gdp_obs ~= 99999);  % Months where quarterly GDP is observed
sub  = caca(idx, :);            % Keep only those quarterly GDP rows
corr(sub(:,1), sub(:,2), 'Rows','complete')
%% PLOT %%
% Extra code to read and convert dates for the plot
filename = fullfile(project_path, 'Final_dataset_final.xlsx');
dates_raw = readcell(filename, ...
                     'Sheet', 'Monthlydata2', ...
                     'Range', 'A2:A313');
% Convert cell column to something MATLAB can plot
if isnumeric(dates_raw{1})
    % Case 1: Excel serial dates
    dates = datetime(cell2mat(dates_raw), 'ConvertFrom', 'excel');
elseif isdatetime(dates_raw{1})
    % Case 2: already datetime
    dates = vertcat(dates_raw{:});
else
    % Case 3: text dates
    dates = datetime(string(dates_raw), 'InputFormat','yyyy-MM-dd');
end

%Plot
idx_gdp = find(gdp_obs ~= 99999);
figure;
plot(dates(idx_gdp), gdp_obs(idx_gdp), 'o-', 'LineWidth', 1.5);
hold on;
plot(dates(idx_gdp), gdp2(idx_gdp), 's-', 'LineWidth', 1.5);
hold off;
legend('Observed GDP','Factor-implied GDP','Location','best');
title('Observed GDP vs factor-implied GDP');
xlabel('Date');
ylabel('GDP growth');
grid on;

%% PLOT ESTIMATED FACTOR %%
% The state vector is ordered as:
% [f(t+3), f(t+2), f(t+1), f(t), f(t-1), f(t-2), f(t-3), f(t-4), ...]
% Therefore the estimated contemporaneous factor is column 4.
estimated_factor = filter(:,4);
figure;
plot(dates, estimated_factor, 'LineWidth', 1.6);
yline(0, '--', 'LineWidth', 1.0);

title('Estimated Common Factor');
xlabel('Date');
ylabel('Standardized factor');
grid on;
%% PLOT ESTIMATED FACTOR AND OBSERVED GDP %%
estimated_factor = filter(:,4);
raw = xlsread(fullfile(project_path, 'Final_dataset_final.xlsx'), 1, 'B2:I313');
gdp_obs = raw(:,1);
idx_gdp = find(gdp_obs ~= 99999);
gdp_obs_std = (gdp_obs(idx_gdp) - megdp) ./ stdgdp;
figure;
plot(dates, estimated_factor, 'LineWidth', 1.6);
hold on;
plot(dates(idx_gdp), gdp_obs_std, 'o-', ...
    'LineWidth', 1.4, ...
    'MarkerSize', 4);
yline(0, '--', 'LineWidth', 1.0);
hold off;
title('Estimated Common Factor and Observed GDP');
xlabel('Date');
ylabel('Standardized value');
legend('Estimated common factor','Observed GDP standardized','Location','best');
grid on;
%% GDP FORECAST NEXT TWO QUARTERS: factor-only GDP without idiosyncratic component  %%
[R,Q,H,F]=matrices(x);
% Use factor-only GDP equation
H2=H;
H2(1,9:13)=0;   % Remove GDP-specific idiosyncratic component from GDP equation
state=filter(end,:)';
forecast_out=zeros(8,6);
for i=1:6
    state=F*state;                 % Forecast state one month ahead
    forecast_out(:,i)=H2*state;    % Convert forecasted state into fitted observed variables
end
gdp_forecast_next_two_quarters=[forecast_out(1,1);forecast_out(1,4)]*stdgdp+megdp;
disp('GDP forecast next two quarters:')
disp('Q2 2026:')
disp(gdp_forecast_next_two_quarters(1))
disp('Q3 2026:')
disp(gdp_forecast_next_two_quarters(2))
%% GDP FORECAST Q2 AND Q3 2026 - FULL FITTED GDP WITH IDIOSYNCRATIC COMPONENT %%
[R_full,Q_full,H_full,F_full] = matrices(x);
state_full = filter(end,:)';
forecast_out_full = zeros(8,4);   % Need up to September 2026
for i = 1:4
    state_full = F_full*state_full;
    forecast_out_full(:,i) = H_full*state_full;
end
% Since the sample ends in May 2026:
% i = 1 -> June 2026 = Q2 2026
% i = 4 -> September 2026 = Q3 2026
gdp_forecast_full_Q2_Q3 = [forecast_out_full(1,1); forecast_out_full(1,4)]*stdgdp + megdp;
disp('Full fitted GDP forecast:')
disp('Q2 2026:')
disp(gdp_forecast_full_Q2_Q3(1))
disp('Q3 2026:')
disp(gdp_forecast_full_Q2_Q3(2))
%% PLOT OBSERVED GDP, FACTOR-IMPLIED GDP AND FACTOR-ONLY FORECASTS %%
idx_gdp = find(gdp_obs ~= 99999);
forecast_dates = [datetime(2026,6,1); datetime(2026,9,1)];
forecast_values = gdp_forecast_next_two_quarters;
observed_blue = [0.0000 0.4470 0.7410];
forecast_red = [0.8000 0.0000 0.0000];
figure('Color','w');
plot(dates(idx_gdp), gdp_obs(idx_gdp), '-o', ...
    'LineWidth', 1.7, ...
    'MarkerSize', 3, ...
    'MarkerFaceColor', observed_blue, ...
    'MarkerEdgeColor', observed_blue, ...
    'Color', observed_blue);
hold on;
plot(dates(idx_gdp), gdp2(idx_gdp), ':', ...
    'LineWidth', 2.2, ...
    'Color', forecast_red);
plot([dates(idx_gdp(end)); forecast_dates(1)], ...
     [gdp2(idx_gdp(end)); forecast_values(1)], ...
     '--', ...
     'LineWidth', 1.8, ...
     'Color', forecast_red, ...
     'HandleVisibility','off');
plot(forecast_dates, forecast_values, 'd--', ...
    'LineWidth', 1.8, ...
    'MarkerSize', 7, ...
    'Color', forecast_red, ...
    'MarkerFaceColor', 'w');
hold off;
title('Observed GDP, Factor-Implied GDP, and Forecasts');
xlabel('Date');
ylabel('GDP Growth');
legend('Observed GDP','Factor-implied GDP','Factor-implied GDP forecast', ...
    'Location','southwest', ...
    'Orientation','horizontal');
grid on;
box on;
xlim([dates(idx_gdp(1)) forecast_dates(end)]);
%% FACTOR LOADINGS AND SIGNIFICANCE TESTS %%
% Variable names in the same order as the dataset columns
var_names = {'GDP','IP','Construction','Vehicle sales','Employment','Stock index','Exports','CLI'}';
% Factor loadings are the first 8 estimated parameters
loadings = x(1:8);
% Standard errors from inverse Hessian
se_loadings = std(1:8);
% t-statistics
t_stats = loadings ./ se_loadings;
% Two-sided asymptotic p-values using normal approximation
p_values = 2*(1 - normcdf(abs(t_stats)));
% Build results table
loading_table = table(var_names, loadings, se_loadings, t_stats, p_values, ...
    'VariableNames', {'Variable','Factor_loading','Std_error','t_stat','p_value'});

disp('Factor loading significance tests:')
disp(loading_table)

%% HELPER FUNCTIONS
function [ fun ] = ofn( th )    % I am looking fo the optimal values of the th.
%OFN Summary of this function goes here
    % Detailed explanation goes here
    % local like,beta00,P00,it,beta10,beta11,n10,fun,Hit,mit,Rit,
    % R,F10,Q,P10,P11,W;

   global yv filter n vfq capt index pnk filterptt;           % Spesifying global variables
   global H;

   [R,Q,H,F]=matrices(th);                  % Given th, we obtain matrices R, Q, H, F
   beta00=zeros(pnk,1);                      % Matrix (10x1)
   P00=eye(pnk);                             % Identity Matrix (10x10)
   like=zeros(capt,1);                    % Matrix (T-1x1)

   %% KALMAN FILTER

   it=1;                                    % kalman filter iterations
   while it<=capt;                        % While iteration number is smaller than or equal to number of observations

      % Set row of the H matrix to zero if it is not observed
      Hit = bsxfun(@times,index(it,:)',H);  %The index multiplying element by element.
      % In contrast, set R to zero if it is observed
      Rit = diag(bsxfun(@times,(1-index(it,:)),R));   %Rit=diagrv(zeros(ny,ny),(1-index(it,:))'.*R);

      beta10=F*beta00;                      % Prediction equations
      P10=F*P00*F'+Q;

      n10=yv(it,:)'-(Hit*beta10);             % Error forecast
      F10=Hit*P10*Hit'+Rit;


      like(it)=-0.5*(log(2*pi*det(F10))+(n10'/F10)*n10);    % Likelihood function

      K=P10*(Hit'/F10);                       % Kalman gain: how I update the infomation given the errors, but now I have errors that are zero.

      beta11=beta10+K*n10;                  % Updating equations
      filter(it,:)=beta11';
      P11=P10-K*Hit*P10;
      %filterptt(it,:,:)=P11;

      beta00=beta11;
      P00=P11;

      it=it+1;                              %Iterating
   end

     fun=-(sum(like(20 ...
         :end),1));                     % Sum of the likelihood

end

function [Rs,Qs,Hs,Fs]=matrices(z)
          global vfq vector;
           %-------------------------------------------------------------%
           %       Procedure to obtain Kalman matrices
           %--------------------------------------------------------------%

           Rs=ones(1,8);                   % Empty matrix (1 x 8)
           h01=[zeros(1,3) vector'*z(1) vector' zeros(1,14)];
           h_ip=[zeros(1,3) z(2) zeros(1,9) 1 zeros(1,13)];
           h_construction=[zeros(1,3) z(3) zeros(1,11) 1 zeros(1,11)];
           h_vehicle=[zeros(1,3) z(4) zeros(1,13) 1 zeros(1,9)];
           h_employment=[zeros(1,3) z(5) zeros(1,15) 1 zeros(1,7)];
           h_stock=[zeros(1,3) z(6) zeros(1,17) 1 zeros(1,5)];
           h_exports=[zeros(1,3) z(7) zeros(1,19) 1 zeros(1,3)];
           h_cli=[z(8) zeros(1,24) 1 0];    % CLI loads on f(t+3)
           Hs=[h_ip; h_construction; h_vehicle; h_employment; h_stock; h_exports; h_cli];
           Hs=[h01; Hs];

        z0=z(9:10);
        z1=z(11:12);
        z2=z(13:14);
        z3=z(15:16);
        z4=z(17:18);
        z5=z(19:20);
        z6=z(21:22);
        z7=z(23:24);
        z8=z(25:26);


        f1=[z0' zeros(1,25)];                % Manually creating rows of matrix F
        f1a=[eye(7) zeros(7,20)];
        f2=[zeros(1,8) z1' zeros(1,17)];
        f2a=[zeros(4,8) eye(4) zeros(4,15)];
        f3=[zeros(1,13) z2' zeros(1,12)];
        f3a=[zeros(1,13) 1 zeros(1,13)];
        f4=[zeros(1,15) z3' zeros(1,10)];
        f4a=[zeros(1,15) 1 zeros(1,11)];
        f5=[zeros(1,17) z4' zeros(1,8)];
        f5a=[zeros(1,17) 1 zeros(1,9)];
        f6=[zeros(1,19) z5' zeros(1,6)];
        f6a=[zeros(1,19) 1 zeros(1,7)];
        f7=[zeros(1,21) z6' zeros(1,4)];
        f7a=[zeros(1,21) 1 zeros(1,5)];
        f8=[zeros(1,23) z7' zeros(1,2)];
        f8a=[zeros(1,23) 1 zeros(1,3)];
        f9=[zeros(1,25) z8'];
        f9a=[zeros(1,25) 1 zeros(1,1)];

        Fs=[f1;f1a;f2;f2a;f3;f3a;f4;f4a;f5;f5a;f6;f6a;f7;f7a;f8;f8a;f9;f9a]; % Concatenating matrix Fs


z2=[vfq 0 0 0 0 0 0 0 z(27) 0 0 0 0 z(28) 0 z(29) 0 z(30) 0 z(31) 0 z(32) 0 z(33) 0 z(34) 0];
z2=(z2).^2;
   Qs=diag(z2);

end

function [data2]=relleno(data,va)
   rd=size(data,1);
   cd=size(data,2);
   data2=va*randn(rd,cd);
   j=1;
   while j<=cd
      i=1;
      while i<=rd
         if data(i,j) ~= 99999;
            data2(i,j)=data(i,j);       % put the data back if it is not 99999
         end
         i=i+1;
      end;
      j=j+1;

   end;

end

function [ data2 ] = standard( data )
%STANDARD Summary of this function goes here


   %local data2,datajm,dataj,i,j,datajst;
   data2=data;
   j=1;
   while j<=size(data,2)              % Loop obtains the following for each observation:
      dataj=data(:,j);              % Jeth column extraction
      dataj=dataj(dataj~=99999);    % Select valid data only
      datajm=mean(dataj,1);         % Obtains mean
      datajst=std(dataj,1);         % Obtains standard deviation
      i=1;
      while i<=size(data,1)         %l oop that standardizes each column of data by
                                    % subtracting the mean and deviding by standard deviation
         if data(i,j) ~= 99999
            data2(i,j)=(data(i,j)-datajm)/datajst;
         end
         i=i+1;
      end
   j=j+1;                           % Iteration

   end
end
