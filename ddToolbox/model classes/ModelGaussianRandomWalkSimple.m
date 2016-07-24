%KIRBY DATA IS NOT APPROPRIATE FOR THIS MODEL
% We need experimental paradigms that try to pinpoint the indifference
% point for a set number of delays.

classdef ModelGaussianRandomWalkSimple < Model
	%ModelGaussianRandomWalkSimple

	properties
		AUC_DATA
	end


	methods (Access = public)

		function obj = ModelGaussianRandomWalkSimple(data, varargin)
			obj = obj@Model(data, varargin{:});

			obj.modelType		= 'mixedGRWsimple';
			obj.discountFuncType = 'nonparametric';

			% 'Decorate' the object with appropriate plot functions
			obj.plotFuncs.participantFigFunc = @figParticipantLOGK;
			obj.plotFuncs.clusterPlotFunc = @() []; % null func

			obj.varList.participantLevel = {'discountFraction'};
			% TODO: remove varList as a property of Model base class.
			obj.varList.monitored = {'discountFraction', 'Rpostpred', 'P'};

		end


		function obj = setInitialParamValues(obj)
            % Generate initial values of the leaf nodes
			%nTrials = size(obj.data.observedData.A,2);
			nParticipants = obj.data.nParticipants;
			nUniqueDelays = numel(obj.observedData.uniqueDelays);

			for chain = 1:obj.sampler.mcmcparams.nchains
				obj.initialParams(chain).discountFraction = normrnd(1, 0.1, [nParticipants+1, nUniqueDelays]);
			end
			% TODO: have a function called discountFraction and pass it
			% into this initialParam maker loop
		end



		function conditionalDiscountRates(obj, reward, plotFlag)
			error('Not applicable to this model that calculates log(k)')
		end

		function conditionalDiscountRates_GroupLevel(obj, reward, plotFlag)
			error('Not applicable to this model that calculates log(k)')
		end





		function plot(obj) % overriding from Model base class
			close all

			%% Corner plot of group-level params
			posteriorSamples = obj.mcmc.getSamplesAsMatrix({'varInc_group','alpha_group','epsilon_group'});
			priorSamples = obj.mcmc.getSamplesAsMatrix({'varInc_group_prior','alpha_group_prior','epsilon_group_prior'});
			varLabals = {'varInc_group','alpha_group','epsilon_group'};

			figure(87)
			import mcmc.*
			TriPlotSamples(posteriorSamples,...
				varLabals,...
				'PRIOR', priorSamples,...
				'pointEstimateType','mean');
			drawnow
			myExport('triplot',...
				'saveFolder', obj.saveFolder,...
				'prefix', 'group')


			%% Plot indifference functions for each participant
			obj.calcAUCscores()
			for p=1:obj.data.nParticipants
				% Extract info about a person for plotting purposes
				personInfo = obj.getParticipantData(p);

				% Plotting
				figure(1), clf

                subplot(1,2,1)
				intervals = [50 95];
				plotDiscountFunctionGRW(personInfo, intervals)
				latex_fig(16, 14, 4)
				%set(gca,'XScale','log')
				%axis tight
				%axis square

                subplot(1,2,2)
                uni = mcmc.UnivariateDistribution(obj.AUC_DATA(p).AUCsamples,...
                  'xLabel', 'AUC');

				myExport('discountfunction',...
				'saveFolder', obj.saveFolder,...
				'prefix', personInfo.participantName)
			end
		end





		function personStruct = getParticipantData(obj, p)

			obj = calcAUCscores(obj); % TODO: This is put here as a quick fix.

			% Create a structure with all the useful info about a person
			% p = person number
			participantName = obj.data.IDname{p};
			try
				parts = strsplit(participantName,'-');
				personStruct.participantName = strjoin(parts(1:2),'-');
			catch
				personStruct.participantName = participantName;
			end
			personStruct.delays = obj.data.observedData.uniqueDelays;
			personStruct.dfSamples = obj.extractDiscountFunctionSamples(p);
			personStruct.data = obj.data.getParticipantData(p);
			personStruct.AUCsamples = obj.AUC_DATA(p).AUCsamples;
		end


		function dfSamples = extractDiscountFunctionSamples(obj, personNumber)
			[chains, samples, participants, nDelays] = size(obj.mcmc.samples.discountFraction);
			personSamples = squeeze(obj.mcmc.samples.discountFraction(:,:,personNumber,:));
			% collapse over chains
			for d=1:nDelays
				dfSamples(:,d) = vec(personSamples(:,:,d));
			end
		end


	end


	methods (Access = protected)

		function obj = calcDerivedMeasures(obj)
			obj = obj.calcAUCscores();
		end

		function obj = calcAUCscores(obj)
			delays = obj.data.observedData.uniqueDelays;
			for p=1:obj.data.nParticipants
				dfSamples = obj.extractDiscountFunctionSamples(p);
				obj.AUC_DATA(p).AUCsamples = calculateAUC(delays,dfSamples, false);
				obj.AUC_DATA(p).name  = obj.data.participantFilenames{p};
			end
		end

	end
	
	methods (Static)
		
		function observedData = constructObservedDataForMCMC(all_data)
			%% Call superclass method to prepare the core data
			observedData = constructObservedDataForMCMC@Model(all_data);
			
			%% Now add model specific observed data
			observedData.uniqueDelays = sort(unique(observedData.DB))';
			observedData.delayLookUp = calcDelayLookup();
			
			function delayLookUp = calcDelayLookup()
				delayLookUp = observedData.DB;
				for n=1: numel(observedData.uniqueDelays)
					delay = observedData.uniqueDelays(n);
					delayLookUp(observedData.DB==delay) = n;
				end
			end
		end
		
		%% FYI
		% 			% **** Observed variables below are for the Gaussian Random
		% 			% Walk model ****
		% 			%
		% 			% Create a lookup table, for a given [participant,trial], this
		% 			% is the index of DB.
		%
		% 			% If we insert additional delays into this vector
		% 			% (uniqueDelays), then the model will interpolate between the
		% 			% delays that we have data for.
		% 			% If you do not want to interpolate any delays, then set :
		% 			%  interpolation_delays = []
		%
		% % 			unique_delays_from_data = sort(unique(obj.observedData.DB))';
		% % 			% optionally add interpolated delays ~~~~~~~~~~~~~~~~~~~~~~~~~~~
		% % 			add_interpolated_delays = true;
		% % 			if add_interpolated_delays
		% % 				interpolation_delays =  [ [7:7:365-7] ...
		% % 					[7*52:7:7*80]]; % <--- future
		% % 				combined = [unique_delays_from_data interpolation_delays];
		% % 				obj.observedData.uniqueDelays = sort(unique(combined));
		% % 			else
		% % 				obj.observedData.uniqueDelays = [0.01 unique_delays_from_data];
		% % 			end
		% % 			% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		% %
		% % 			% Now we create a lookup table [participants,tials] full of
		% % 			% integers which point to the index of the delay value in
		% % 			% uniqueDelays
		% % 			temp = obj.observedData.DB;
		% % 			for n=1: numel(obj.observedData.uniqueDelays)
		% % 				delay = obj.observedData.uniqueDelays(n);
		% % 				temp(obj.observedData.DB==delay) = n;
		% % 			end
		% % 			obj.observedData.delayLookUp = temp;
		% 		end
		
	end

end
