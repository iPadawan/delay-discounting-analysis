function plotPsychometricFunc(pSamples, modeVals)


% This is the Psychometric function ---------------------------------------
%fh = @(x,params) params(:,1) + (1-2*params(:,1)) * normcdf( (x ./ params(:,2)) , 0, 1);
%fh = @FAST_PSYCHOMETRIC;
% This is converted to work FAST ------------------------------------------
%display('**** SPEED THIS CODE UP ****')
fh = @(x,params) bsxfun(@plus,...
	params(:,1),...
	bsxfun(@times, ...
	(1-2*params(:,1)),...
	normcdf( bsxfun(@rdivide, x, params(:,2) ) , 0, 1)) );
% -------------------------------------------------------------------------

samples(:,1) = pSamples.epsilon;
samples(:,2) = pSamples.alpha;

mcmc.PosteriorPrediction1D(fh,...
    'xInterp',linspace(-200,200,200),... % TODO: make this a function of alpha?
    'samples',samples,...
    'ciType','examples',...
    'variableNames', {'$V^B-V^A$', 'P(choose delayed)'});

return
