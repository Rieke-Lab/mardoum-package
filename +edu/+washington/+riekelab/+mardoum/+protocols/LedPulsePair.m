classdef LedPulsePair < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents a set of rectangular pulse stimuli to a specified LED and records from a specified amplifier.
    
    properties
        led1                            % Output LED
        led2
        preTime = 10                    % Pulse leading duration (ms)
        stimTime = 100                  % Pulse duration (ms)
        tailTime = 400                  % Pulse trailing duration (ms)
        lightAmplitude = 0.1            % Pulse amplitude (V or norm. [0-1] depending on LED units)
        lightMean = 0                   % Pulse and LED background mean (V or norm. [0-1] depending on LED units)
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
    end
    
    properties (Hidden)
        led1Type
        led2Type
        ampType
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led1, obj.led1Type] = obj.createDeviceNamesProperty('LED'); % grabs options for LED dropdown menu
            [obj.led2, obj.led2Type] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);
            
            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end
        
        % Preview would need some work to handle possibilities 
%         function p = getPreview(obj, panel)
%             p = symphonyui.builtin.previews.StimuliPreview(panel, @()obj.createLedStimulus());
%         end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                    'baselineRegion', [0 obj.preTime], ...
                    'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
                    'baselineRegion1', [0 obj.preTime], ...
                    'measurementRegion1', [obj.preTime obj.preTime+obj.stimTime], ...
                    'baselineRegion2', [0 obj.preTime], ...
                    'measurementRegion2', [obj.preTime obj.preTime+obj.stimTime]);
            end
            
            device = obj.rig.getDevice(obj.led);
            % TODO: set appropriate backgrounds for 1 or 2 led stimulus
            device.background = symphonyui.core.Measurement(obj.lightMean, device.background.displayUnits);
        end
        
        function stim = createLedStimulusOneFlash(obj, preTime, stimTime, tailTime, lightMean, lightAmplitude)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = preTime;
            gen.stimTime = stimTime;
            gen.tailTime = tailTime;
            gen.amplitude = lightAmplitude;
            gen.mean = lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function stim = createLedStimulusTwoFlashes(obj)
            firstFlashStim = obj.createLedStimulusOneFlash( ...
                obj.preTime, ...
                obj.flashDuration, ...
                obj.timeBetweenFlashes + obj.flashDuration + obj.tailTime, ...
                obj.flash1Mean, ...
                obj.flash1Amplitude);
            
            secondFlashStim = obj.createLedStimulusOneFlash( ...
                obj.preTime + obj.flashDuration + obj.timeBetweenFlashes, ...
                obj.flashDuration, ...
                obj.tailTime, ...
                0, ...
                obj.flash2Amplitude);
            
            sumGen = symphonyui.builtin.stimuli.SumGenerator();
            sumGen.stimuli = {firstFlashStim.generate(), secondFlashStim.generate()};
            stim = sumGen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            if strcmp(obj.led1, obj.led2)
                if obj.flash1Mean ~= obj.flash2Mean
                   error('when using same led, means must be the same'); 
                end
                
                epoch.addStimulus(obj.rig.getDevice(obj.led1), obj.createLedStimulusTwoFlashes());
            else
                epoch.addStimulus(obj.rig.getDevice(obj.led1), ...
                    obj.createLedStimulusOneFlash( ...
                    obj.preTime, ...
                    obj.flashDuration, ...
                    obj.timeBetweenFlashes + obj.flashDuration + obj.tailTime, ...
                    obj.flash1Mean, ...
                    obj.flash1Amplitude));
                epoch.addStimulus(obj.rig.getDevice(obj.led2), ...
                    obj.createLedStimulusOneFlash( ...
                    obj.preTime + obj.flashDuration + obj.timeBetweenFlashes, ...
                    obj.flashDuration, ...
                    obj.tailTime, ...
                    obj.flash2Mean, ...
                    obj.flash2Amplitude));
            end
            
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            %TODO add background to all LEDs
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
        function a = get.amp2(obj)
            amps = obj.rig.getDeviceNames('Amp');
            if numel(amps) < 2
                a = '(None)';
            else
                i = find(~ismember(amps, obj.amp), 1);
                a = amps{i};
            end
        end
        
    end
    
end
