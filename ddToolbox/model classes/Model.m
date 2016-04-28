classdef Model < handle
	%Model Base class to provide basic functionality
	%	xxxx

	properties (Access = public)
		modelType % string
		data % handle to Data class
		sampler % handle to SamplerWrapper class
		variables % array of variables
		varList
		saveFolder
		mcmc % handle to mcmc fit object
		plotFuncs % structure of function handles
		discountFuncType
		pointEstimateType
	end

	methods(Abstract, Access = public)
	end

	methods (Access = public)

		function obj = Model(data, saveFolder, varargin)
			p = inputParser;
			p.FunctionName = mfilename;
			p.addRequired('data', @(x) isa(x,'DataClass'));
			p.addRequired('saveFolder', @isstr);
			p.addParameter('pointEstimateType','mode',@(x) any(strcmp(x,{'mean','median','mode'})));
			p.parse(data, saveFolder, varargin{:});
			% add p.Results fields into obj
			fields = fieldnames(p.Results);
			for n=1:numel(fields)
				obj.(fields{n}) = p.Results.(fields{n});
			end
		end

		function varNames = extractLevelNVarNames(obj, N)
			varNames={};
			for var = each(fieldnames(obj.variables))
				if obj.variables.(var).analysisFlag == N
					varNames{end+1} = var;
				end
			end
		end

		function bool = isGroupLevelModel(obj)
			% we determine if the model has group level parameters by checking if
			% we have a 'groupLevel' subfield in the varList.
			if isfield(obj.varList,'groupLevel')
				bool = ~isempty(obj.varList.groupLevel);
			end
		end

		% MIDDLE-MAN METHODS ================================================

		function conductInference(obj)
			obj.mcmc = obj.sampler.conductInference( obj , obj.data );
		end

		function setBurnIn(obj, nburnin)
			obj.sampler.setBurnIn(nburnin)
		end

		function setMCMCtotalSamples(obj, totalSamples)
			obj.sampler.setMCMCtotalSamples(totalSamples)
		end

		function setMCMCnumberOfChains(obj, nchains)
			obj.sampler.setMCMCnumberOfChains(nchains)
		end

		function plotMCMCchains(obj,vars)
			obj.mcmc.plotMCMCchains(vars);
		end

		function paramEstimateTable = exportParameterEstimates(obj, varargin)
			paramEstimateTable = obj.mcmc.exportParameterEstimates(...
				obj.varList.participantLevel,... %obj.extractLevelNVarNames(1),... % Participant-level
				obj.varList.groupLevel,...obj.extractLevelNVarNames(2),...  % group-level)
				obj.data.IDname,...
				obj.saveFolder,...
				obj.pointEstimateType,...
				varargin{:});
		end




		% ===============================================================
		% WHERE SHOULD THESE FUNCTIONS LIVE?

		function conditionalDiscountRates(obj, reward, plotFlag)
			% Extract and plot P( log(k) | reward)
			warning('THIS METHOD IS A TOTAL MESS - PLAN THIS AGAIN FROM SCRATCH')
			obj.conditionalDiscountRates_ParticipantLevel(reward, plotFlag)

			if plotFlag
				removeYaxis
				title(sprintf('$P(\\log(k)|$reward=$\\pounds$%d$)$', reward),'Interpreter','latex')
				xlabel('$\log(k)$','Interpreter','latex')
				axis square
			end
		end

		function conditionalDiscountRates_ParticipantLevel(obj, reward, plotFlag)
			nParticipants = obj.data.nParticipants;
			%count=1;
			for p = 1:nParticipants
				params(:,1) = obj.mcmc.getSamplesFromParticipantAsMatrix(p, {'m'});
				params(:,2) = obj.mcmc.getSamplesFromParticipantAsMatrix(p, {'c'});
				% ==============================================
				[posteriorMean(p), lh(p)] =...
					calculateLogK_ConditionOnReward(reward, params, plotFlag);
				%lh(count).DisplayName=sprintf('participant %d', p);
				%row(count) = {sprintf('participant %d', p)};
				% ==============================================
				%count=count+1;
			end
			warning('GET THESE NUMBERS PRINTED TO SCREEN')
			% 			logkCondition = array2table([posteriorMode'],...
			% 				'VariableNames',{'logK_posteriorMode'},...)
			% 				'RowNames', num2cell([1:nParticipants]) )
		end








































		% **********************************************************************
		% **********************************************************************
		% PLOTTING *************************************************************
		% **********************************************************************
		% **********************************************************************
		% This plot method is highly unsatisfactory. We have a whole bunch of logic
		% which decides on the properties of the model (hierachical or not) and
		% (logk vs magnitude effect). It then uses a bunch of get methods in order
		% to grab the data in the appropriate format. We then pass this data to plot
		% functions/classes.
		%
		% Thinking needs to be done about the best way to refactor all this mess.





		function plot(obj)
			close all

			% IDEAS:
			% - Loop over participants (and group if there is one) and create an array of objects of a new participant class. This class will contain all the data for that person, as well as the plotting functions.
			%
			% - Or....



% Temporarily(?) removing this, because it's not really very useful
% This does NOT utilise the user-specified pointEstimateType, currently.
% 			% UNIVARIATE SUMMARY STATISTICS ---------------------------------
% 			% We are going to add on group level inferences to the end of the
% 			% list. This is because the group-level inferences an be
% 			% seen as inferences we can make about an as yet unobserved
% 			% participant, in the light of the participant data available thus
% 			% far.
% 			IDnames = obj.data.IDname;
% 			if obj.isGroupLevelModel()
% 				IDnames{end+1}='GROUP';
% 			end
% 			% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
% 			obj.mcmc.figUnivariateSummary(IDnames, obj.varList.participantLevel, obj.pointEstimateType)
% 			% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
% 			latex_fig(16, 5, 5)
% 			myExport('UnivariateSummary',...
% 				'saveFolder',obj.saveFolder,...
% 				'prefix', obj.modelType)
% 			% --------------------------------------------------------------------







			%% PARTICIPANT LEVEL
			% We will ALWAYS have participants. So we will ALWAYS want to render some plots that allow us to understand the participant-level inferences made.
			% This might mean that a Participant class might be a sensible thing, and that could consist of participant data and plot methods.


			if obj.isGroupLevelModel()
				participant_level_prior_variables = cellfun(...
					@getPriorOfVariable,...
					obj.varList.groupLevel,...
					'UniformOutput',false );
			else
				participant_level_prior_variables = cellfun(...
					@getPriorOfVariable,...
					obj.varList.participantLevel,...
					'UniformOutput',false );
			end



			% TODO ??????????????????
			opts.maxlogB	= max(abs(obj.data.observedData.B(:)));
			opts.maxD		= max(obj.data.observedData.DB(:));
			% ??????????????????


			% obj.plotFuncs.participantFigFunc is a handle to a function that will either plot LOGK or ME.
			for n = 1:obj.data.nParticipants
				fh = figure;
				fh.Name=['participant: ' obj.data.IDname{n}];

				% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
				obj.plotFuncs.participantFigFunc(obj.mcmc.getSamplesAtIndex(n, obj.varList.participantLevel),...
					obj.pointEstimateType,...
					'pData', obj.data.getParticipantData(n),...
					'opts',opts);
				% ~~~~~~~~~~~~~~~~~~~~~~~~~~~

				latex_fig(16, 18, 4)
				myExport(obj.data.IDname{n},...
					'saveFolder', obj.saveFolder,...
					'prefix', obj.modelType);
				close(fh)
			end

			% TRIPLOT
			for n = 1:obj.data.nParticipants
				figure(87)

				% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
				TriPlotSamples(obj.mcmc.getSamplesFromParticipantAsMatrix(n, obj.varList.participantLevel),...
					obj.varList.participantLevel,...
					'PRIOR',obj.mcmc.getSamplesAsMatrix(participant_level_prior_variables),...
					'pointEstimateType',obj.pointEstimateType);
				% ~~~~~~~~~~~~~~~~~~~~~~~~~~~

				myExport([obj.data.IDname{n} '-triplot'],...
					'saveFolder', obj.saveFolder,...
					'prefix', obj.modelType);
			end



			%% SUMMARY PLOTS
			switch obj.discountFuncType
				case{'me'} % code smell
					% MC cluster plot
					probMass = 0.5; % <---- 50% prob mass chosen to avoid too much clutter on graph
					% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
					figure(12)
					plotMCclusters(obj.mcmc, obj.data, [1 0 0], probMass, obj.pointEstimateType)
					% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
					myExport('MC_summary',...
						'saveFolder', obj.saveFolder,...
						'prefix', obj.modelType)
					
				case{'logk'}
					% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
					figure(12)
					plotLOGKclusters(obj.mcmc, obj.data, [1 0 0], obj.pointEstimateType)
					% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
					myExport('LOGK_summary',...
						'saveFolder', obj.saveFolder,...
						'prefix', obj.modelType)
			end






			%% GROUP LEVEL ======================================
			% SOME but not all models will have group-level inferences. Therefore we only want to proceed with plotting group level parameters if we are dealing with such a model.

			if ~obj.isGroupLevelModel()
				return
			end

			group_level_prior_variables = cellfun(...
				@getPriorOfVariable,...
				obj.varList.groupLevel,...
				'UniformOutput',false );




			% PSYCHOMETRIC PARAMS
			% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
			figPsychometricParamsHierarchical(obj.mcmc, obj.data)
			myExport('PsychometricParams',...
				'saveFolder', obj.saveFolder,...
				'prefix', obj.modelType)
			% ~~~~~~~~~~~~~~~~~~~~~~~~~~~







			% TRIPLOT
			import mcmc.*
			posteriorSamples = obj.mcmc.getSamplesAsMatrix(obj.varList.groupLevel);
			priorSamples = obj.mcmc.getSamplesAsMatrix(group_level_prior_variables);

			figure(87)
			% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
			TriPlotSamples(posteriorSamples,...
				obj.varList.groupLevel,...
				'PRIOR', priorSamples,...
				'pointEstimateType',obj.pointEstimateType);
			% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
			myExport('GROUP-triplot',...
				'saveFolder', obj.saveFolder,...
				'prefix', obj.modelType)




			% GROUP (UNSEEN PARTICIPANT) PLOT

			% strip the '_group' off of variablenames
			for n=1:numel(obj.varList.groupLevel)
				temp=regexp(obj.varList.groupLevel{n},'_','split');
				groupLevelVarName{n} = temp{1};
			end
% 			% get point estimates. TODO: this can be a specific method in mcmc.
% 			for n=1:numel(obj.varList.groupLevel)
% 				pointEstimate.(groupLevelVarName{n}) =...
% 					obj.mcmc.getStats('mean', obj.varList.groupLevel{n});
% 			end

			[pSamples] = obj.mcmc.getSamples(obj.varList.groupLevel);
			% flatten
			for n=1:numel(obj.varList.groupLevel)
				pSamples.(obj.varList.groupLevel{n}) = vec(pSamples.(obj.varList.groupLevel{n}));
			end
			% rename
			pSamples = renameFields(...
				pSamples,...
				obj.varList.groupLevel,...
				groupLevelVarName);


			% TODO ??????????????????
			opts.maxlogB	= max(abs(obj.data.observedData.B(:)));
			opts.maxD		= max(obj.data.observedData.DB(:));
			% ???????????????????????

% 			% get group level pointEstimates
% 			pointEstimates = obj.mcmc.getParticipantPointEstimates(1, obj.varList.groupLevel);
% 			pointEstimates = renameFields(...
% 				pointEstimates,...
% 				obj.varList.groupLevel,...
% 				groupLevelVarName);

			% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
			figure
			obj.plotFuncs.participantFigFunc(pSamples,...
				obj.pointEstimateType,...
				'opts', opts)
			latex_fig(16, 18, 4)
			myExport('GROUP',...
				'saveFolder', obj.saveFolder,...
				'prefix', obj.modelType)
			% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
		end


















		function posteriorPredictive(obj)
			warning('THIS CODE IS IN-PROGRESS, AND EXPERIMENTAL')

			%% Calculation
			% Calculate log posterior odds of data under the model and a
			% control model where prob of responding is 0.5.
			prob = @(responses, predicted) prod(binopdf(responses, ...
				ones(size(responses)),...
				predicted));
			nParticipants = obj.data.nParticipants;
			for p=1:nParticipants
				participantResponses = obj.data.participantLevel(p).data.R;% <-- replace with a get method
				participant(p).predicted = obj.sampler.getParticipantPredictedResponses(p);
				pModel = prob(participantResponses, participant(p).predicted');
				controlPredictions = ones(size(participantResponses)) .* 0.5;
				pRandom = prob(participantResponses, controlPredictions);
				logSomething(p) = log( pModel ./ pRandom);
			end


			%% Plotting
			figure(77), clf, colormap(gray)
			for p=1:nParticipants
				subplot(nParticipants,1,p)
				% plot predicted probability of choosing delayed
				bar(participant(p).predicted,'BarWidth',1)
				if p<nParticipants, set(gca,'XTick',[]), end
				box off
				% plot response data
				hold on
				plot([1:obj.data.participantLevel(p).trialsForThisParticant],... % <-- replace with a get method
					obj.data.participantLevel(p).data.R,... % <-- replace with a get method
					'o')
				addTextToFigure('TR',...
					sprintf('%s: %3.2f\n', obj.data.IDname{p}, logSomething(p)),...
					10);
			end
			xlabel('trials')
		end

	end

end