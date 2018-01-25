classdef LedPulsePair < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents a pair of LED pulses using either same or different LEDs.
    
    properties
        led1                            % Output LED, pulse 1
        led2                            % Output LED, pulse 2
        
        preTime = 100                   % Pulse leading duration (ms)
        stimTime = 10                   % Pulse duration (ms)
        betweenOnsetsTime = 100         % Time between onsets of pulses in pair (ms)
        tailTime = 500                  % Pulse trailing duration (ms)
        
        led1Amplitude = 0.1             % Pulse 1 amplitude (V or norm. [0-1] depending on LED units)
        led2Amplitude = 0.1             % Pulse 2 amplitude
        led1Mean = 0                    % Pulse and LED 1 background mean (V or norm. [0-1] depending on LED units)
        led2Mean = 0                    % Pulse and LED 2 background mean
        
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
        
        % Preview would need to handle multiple scenarios
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
            
            device1 = obj.rig.getDevice(obj.led1);
            device1.background = symphonyui.core.Measurement(obj.led1Mean, device1.background.displayUnits);
            if strcmp(obj.led1, obj.led2)
                if obj.led1Mean ~= obj.led2Mean
                    error('When using same LED for both pulses, means must be equal');
                end
            else
                device2 = obj.rig.getDevice(obj.led2);
                device2.background = symphonyui.core.Measurement(obj.led2Mean, device2.background.displayUnits);
            end
        end
        
        function stim = createLedStimulusSingle(obj, ledID, preTime, stimTime, tailTime, lightMean, lightAmplitude)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = preTime;
            gen.stimTime = stimTime;
            gen.tailTime = tailTime;
            gen.mean = lightMean;
            gen.amplitude = lightAmplitude;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.(ledID)).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function stim = createLedStimulusPairSame(obj)
            firstPulseStim = obj.createLedStimulusSingle( ...
                'led1', ...
                obj.preTime, ...
                obj.stimTime, ...
                obj.betweenOnsetsTime + obj.tailTime, ...
                obj.led1Mean, ...
                obj.led1Amplitude);
            
            secondPulseStim = obj.createLedStimulusSingle( ...
                'led2', ...
                obj.preTime + obj.betweenOnsetsTime, ...
                obj.stimTime, ...
                obj.tailTime, ...
                0, ...
                obj.led2Amplitude);
            
            sumGen = symphonyui.builtin.stimuli.SumGenerator();
            sumGen.stimuli = {firstPulseStim.generate(), secondPulseStim.generate()};
            stim = sumGen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            if strcmp(obj.led1, obj.led2)
                % use SumGenerator
                epoch.addStimulus(obj.rig.getDevice(obj.led1), obj.createLedStimulusPairSame());
            else
                % run two simultaneous pulse protocols
                epoch.addStimulus(obj.rig.getDevice(obj.led1), obj.createLedStimulusSingle( ...
                    'led1', ...
                    obj.preTime, ...
                    obj.stimTime, ...
                    obj.betweenOnsetsTime + obj.tailTime, ...
                    obj.led1Mean, ...
                    obj.led1Amplitude));
                epoch.addStimulus(obj.rig.getDevice(obj.led2), obj.createLedStimulusSingle( ...
                    'led2', ...
                    obj.preTime + obj.betweenOnsetsTime, ...
                    obj.stimTime, ...
                    obj.tailTime, ...
                    obj.led2Mean, ...
                    obj.led2Amplitude));
            end
            
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device1 = obj.rig.getDevice(obj.led1);
            interval.addDirectCurrentStimulus(device1, device1.background, obj.interpulseInterval, obj.sampleRate);
            if ~strcmp(obj.led1, obj.led2)
                device2 = obj.rig.getDevice(obj.led2);
                interval.addDirectCurrentStimulus(device2, device2.background, obj.interpulseInterval, obj.sampleRate);
            end
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
