classdef PerforatedPatchAccessMonitor < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents a set of rectangular pulse stimuli to a specified LED and records from a specified amplifier.
    
    properties
        voltageMeasurementTime = 100    % Time over which to measure/average voltage (ms)
        interpulseInterval = 5          % Duration between pulses (s)
        numberOfMeasurements = 1000     % Number of times to measure membrane potential
        
        ledPulseEpochEvery = 12         % Number of voltage measurements before a flash response measurement 
        ledPulsesToOverlay = 4          % Number of pulse responses to overlay in monitoring figure
        
        led                             % Output LED for flash response measurement
        preTime = 10                    % Pulse leading duration (ms)
        stimTime = 100                  % Pulse duration (ms)
        tailTime = 400                  % Pulse trailing duration (ms)
        lightAmplitude = 0.1            % Pulse amplitude (V or norm. [0-1] depending on LED units)
        lightMean = 0                   % Pulse and LED background mean (V or norm. [0-1] depending on LED units)
        
        amp                             % Input amplifier
    end
    
    properties (Hidden)
        ledType
        ampType
    end
    
    properties (Dependent)
       totalNumEpochs % will figure out how many led pulses will be given when making obj.numberOfMeasurements, then add the two 
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()obj.createLedStimulus());
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.mardoum.figures.PerforatedPatchMonitoringFigure',...
                obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.led), obj.ledPulsesToOverlay);
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.lightMean, device.background.displayUnits);
        end
        
        function stim = createLedStimulus(obj)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.lightAmplitude;
            gen.mean = obj.lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function stim = createVoltageMeasurementStimulus(obj)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = 0;
            gen.stimTime = obj.voltageMeasurementTime;
            gen.tailTime = 0;
            gen.amplitude = 0;
            gen.mean = obj.lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            if obj.isLedPulseEpoch(obj.numEpochsPrepared)
                epoch.addParameter('isLedPulseEpoch', true);
                stimulus = obj.createLedStimulus();
            else
                epoch.addParameter('isLedPulseEpoch', false);
                stimulus = obj.createVoltageMeasurementStimulus();
            end
            
            epoch.addStimulus(obj.rig.getDevice(obj.led), stimulus);
            epoch.addResponse(obj.rig.getDevice(obj.amp));

            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function tf = isLedPulseEpoch(obj, epochNum)
           tf = mod(epochNum, obj.ledPulseEpochEvery + 1) == 0; 
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.totalNumEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.totalNumEpochs;
        end
        
        function value = calculateVoltageMeasurementNumber(obj, epochNum)
            value = epochNum - floor(epochNum / (obj.ledPulseEpochEvery + 1));
        end
        
        function value = calculateLedPulseNumber(obj, epochNum)
            value = floor(epochNum / (obj.ledPulseEpochEvery + 1));
        end
        
        function value = get.totalNumEpochs(obj)
           numLedPulses = floor(obj.numberOfMeasurements / (obj.ledPulseEpochEvery + 1));
           value = obj.numberOfMeasurements + numLedPulses;
        end 
    end    
end

