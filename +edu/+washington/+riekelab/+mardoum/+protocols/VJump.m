classdef VJump < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties
        led                             % Output LED
        preTime = 100                   % Pulse leading duration (ms)
        stimTime = 10                   % Pulse duration (ms)
        tailTime = 1000                 % Pulse trailing duration (ms)
        lightAmplitude = 1              % Pulse amplitude (V)
        lightMean = 0                   % Pulse and background mean (V)
        amp                             % Input amplifier
        pulseAmplitude = 70             % Voltage jump (mV)
        interval = 50                   % Interval after start of LED pulse to start jump (ms)
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
    end
    
    properties (Hidden)
        ledType
        ampType
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.rieke.protocols.RiekeProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @(){obj.createLedStimulus(), obj.createAmpStimulus()});
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.rieke.protocols.RiekeProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                'baselineRegion', [0 obj.preTime], ...
                'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            
            obj.rig.getDevice(obj.led).background = symphonyui.core.Measurement(obj.lightMean, 'V');
        end
        
        function stim = createLedStimulus(obj)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.lightAmplitude;
            gen.mean = obj.lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            
            stim = gen.generate();
        end
        
        function stim = createAmpStimulus(obj)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            device = obj.rig.getDevice(obj.amp);
            
            gen.preTime = obj.preTime + obj.interval;
            gen.stimTime = obj.stimTime + obj.tailTime - obj.interval;
            gen.tailTime = 0;
            gen.amplitude = obj.pulseAmplitude;
            gen.mean = device.background.quantity;
            gen.sampleRate = obj.sampleRate;
            gen.units = device.background.displayUnits;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.rieke.protocols.RiekeProtocol(obj, epoch);
            
            epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus());
            epoch.addStimulus(obj.rig.getDevice(obj.amp), obj.createAmpStimulus());
            epoch.addResponse(obj.rig.getDevice(obj.amp));
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.rieke.protocols.RiekeProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
    end
    
end

