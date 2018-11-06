classdef UniformSpotSeries < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        % parameters for noise
        preTime = 500                   % ms
        stimTime = 5000                 % ms
        tailTime = 500                  % ms
        apertureDiameter = 200          % um
        noiseMean = 0.5                 % (0-1)
        noiseStdv = 0.3                 % Contrast, as fraction of mean
        frameDwell = 1                  % Frames per noise update
        useRandomSeed = true            % false = repeated noise trajectory (seed 0)

        % additional parameters for image-derived sequences
        imageIndex = 1
        runIndex   = 1

        % onlineAnalysis = 'none'
        numberOfCycles = uint16(10)   % Number of epochs to queue
        amp                             % Output amplifier
    end

    properties (Hidden)
        ampType
        backgroundIntensity
        % onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        noiseSeed

        % additional parameters for image-derived sequences
        stimulusFile
        stimulusDataset
        currSequence

        stimulusVector  % temporary, for troubleshooting
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
         
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            % if ~strcmp(obj.onlineAnalysis,'none')
            %     obj.showFigure('edu.washington.riekelab.turner.figures.LinearFilterFigure',...
            %         obj.rig.getDevice(obj.amp),obj.rig.getDevice('Frame Monitor'),...
            %         obj.rig.getDevice('Stage'),...
            %         'recordingType',obj.onlineAnalysis,'preTime',obj.preTime,...
            %         'stimTime',obj.stimTime,'frameDwell',obj.frameDwell,...
            %         'noiseStdv',obj.noiseStdv);
            % end

            % Load data and get luminance trajectories.  Data stored in struct array
            % with each struct(i) having fields: ImageIndex SubjectIndex ImageName ImageMin 
            % ImageMax ImageMean centerTrajectory surroundTrajectory
            resourcesDir = 'C:\Users\Public\Documents\mardoum-package\resources\';
            obj.stimulusFile = 'luminanceSequenceDataset_20181105.mat';
            S = load([resourcesDir, obj.stimulusFile]);
            obj.stimulusDataset = S.DS;

            % % Get random ordering
            % entriesPerImage = length(DS(1).doves.sequence);
            % order = randperm(length(DS) * entriesPerImage);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);

            stimulusGroup = obj.getStimulusGroup();

            if stimulusGroup == 1  % noise epoch
                obj.backgroundIntensity = noiseMean;
                % Determine seed values. At start of epoch, set random stream
                if obj.useRandomSeed
                    obj.noiseSeed = RandStream.shuffleSeed;
                else
                    obj.noiseSeed = 0;
                end
                obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
                epoch.addParameter('noiseSeed', obj.noiseSeed);

            else 
                if stimulusGroup == 2  % image-derived brownian FEM
                    % Pull appropriate stimuli. Scale such that brightest point in original image is 1.0 on the monitor
                    obj.currSequence = obj.stimulusDataset(obj.imageIndex).brownian.sequence(runIndex).center / ...
                         obj.stimulusDataset(obj.imageIndex).img.max;
                elseif stimulusGroup == 3  % image-derived synthetic saccades
                    obj.currSequence = obj.stimulusDataset(obj.imageIndex).synthSaccades.sequence(runIndex).center / ...
                         obj.stimulusDataset(obj.imageIndex).img.max;
                end

                % Set background intensity to the mean over the original image
                obj.backgroundIntensity = obj.stimulusDataset(obj.imageIndex).img.mean / ...
                    obj.stimulusDataset(obj.imageIndex).img.max;

                epoch.addParameter('stimulusFile', obj.stimulusFile);
                epoch.addParameter('sequenceVector', obj.currSequence);
            end

            epoch.addParameter('stimulusGroup', stimulusGroup);
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);

            obj.stimulusVector = [];
        end


        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            % Convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            
            % Create presentation of specified duration
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.noiseMean); % Set background intensity
            
            % Create noise stimulus.            
            rect = stage.builtin.stimuli.Rectangle();
            rect.size = canvasSize;
            rect.position = canvasSize/2;
            p.addStimulus(rect);
            preFrames = round(60 * (obj.preTime/1e3));
            
            stimulusGroup = obj.getStimulusGroup();
            if stimulusGroup == 1
                displayValue = stage.builtin.controllers.PropertyController(rect, 'color',...
                    @(state)getNoiseIntensity(obj, state.time - preFrames));

            else % image-derived
                timeVector = (0:(length(obj.currSequence)-1)) / 60;     % sec  % TODO optional compatibility with doves which is 200 Hz
                displayValue = stage.builtin.controllers.PropertyController(rect, 'color',...
                    @(state)getSeqIntensity(obj, state.time - preFrames, currSequence, timeVector));
            end

            obj.stimulusVector = [obj.stimulusVector; displayValue]
            epoch.addParameter('stimulusVector', obj.stimulusVector);
            p.addController(displayValue);  % add the controller

            function next = getNoiseIntensity(obj, frame)
                persistent intensity;  % store intensity for potential reuse next frame
                if frame < 0  % pre frames. frame 0 starts stimPts
                    intensity = obj.noiseMean;
                else          % in stim frames
                    if mod(frame, obj.frameDwell) == 0  % noise update
                        intensity = obj.noiseMean + obj.noiseStdv * obj.noiseMean * obj.noiseStream.randn;
                    end
                end
                next = intensity;  
            end

            function next = getSeqIntensity(obj, frame, sequence, timeVector)
                if frame < 0  % pre frames. frame 0 starts stimPts
                    next = obj.noiseMean;
                else          % in stim frames
                    if frame > timeVector(end)  % out of eye trajectory, back to mean
                        next = obj.backgroundIntensity;
                    else                       % within eye trajectory and stim time
                        next = interp1(timeVector, sequence, frame);
                    end
                end
            end

            if (obj.apertureDiameter > 0)  % create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.noiseMean;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024);  % circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture);  % add aperture
            end
            
            % Hide during pre & post
            rectVisible = stage.builtin.controllers.PropertyController(rect, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(rectVisible);
        end

        function stimulusGroup = getStimulusGroup(obj)
            stimulusGroup = int8(mod(obj.numEpochsPrepared - 1, 3) + 1);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < 3 * obj.numberOfCycles;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < 3 * obj.numberOfCycles;
        end
    end
    
end