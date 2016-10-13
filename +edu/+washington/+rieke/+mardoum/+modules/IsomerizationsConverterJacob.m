classdef IsomerizationsConverterJacob < symphonyui.ui.Module
    
    properties
        leds
        ledListeners
        species
        photoreceptors
        orderedPhotoreceptorKeys
        figureHandle
    end
    
    properties
        ledPopupMenu
        ndfsField
        gainField
        speciesField
        photoreceptorPopupMenu
        voltsBox
        photoreceptorBoxes
    end
    
    methods
        
        function createUi(obj, figureHandle)
            obj.figureHandle = figureHandle;
        end
        
        function actuallyCreateUI(obj)
            import appbox.*;
            import symphonyui.app.App;
            
            % start by getting some information about the photoreceptors
            % because it will determine the number of rows in the window,
            % and therefore the window's size
            obj.species = obj.findSpecies();
            obj.photoreceptors = obj.findPhotoreceptors();
            obj.orderedPhotoreceptorKeys = obj.orderPhotoreceptorKeys();
            
            
            set(obj.figureHandle, ...
                'Name', 'Isomerizations Converter', ...
                'Position', screenCenter(270, (190 + 30 * (obj.photoreceptors.length + 1))));
            
            mainLayout = uix.VBox( ...
                'Parent', obj.figureHandle);
            
            setupBox = uix.BoxPanel( ...
                'Parent', mainLayout, ...
                'Title', 'Light', ...
                'BorderType', 'none', ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);
            setupLayout = uix.Grid( ...
                'Parent', setupBox, ...
                'Spacing', 7);
            Label( ...
                'Parent', setupLayout, ...
                'String', 'LED:');
            Label( ...
                'Parent', setupLayout, ...
                'String', 'NDFs:');
            Label( ...
                'Parent', setupLayout, ...
                'String', 'Gain:');
            Label( ...
                'Parent', setupLayout, ...
                'String', 'Species:');
            
            obj.ledPopupMenu = MappedPopupMenu( ...
                'Parent', setupLayout, ...
                'String', {' '}, ...
                'HorizontalAlignment', 'left', ...
                'Callback', @obj.onSelectedLed);
            obj.ndfsField = uicontrol( ...
                'Parent', setupLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            obj.gainField = uicontrol( ...
                'Parent', setupLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            obj.speciesField = uicontrol( ...
                'Parent', setupLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            
            Button( ...
                'Parent', setupLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'Callback', @obj.onSelectedLedHelp);
            Button( ...
                'Parent', setupLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'Callback', @obj.onSelectedNdfsHelp);
            Button( ...
                'Parent', setupLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'Callback', @obj.onSelectedGainHelp);
            Button( ...
                'Parent', setupLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'Callback', @obj.onSelectedSpeciesHelp);
            set(setupLayout, ...
                'Widths', [80 -1 22], ...
                'Heights', [23 23 23 23]);
            
            converterBox = uix.BoxPanel( ...
                'Parent', mainLayout, ...
                'Title', 'Converter', ...
                'BorderType', 'none', ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);
            converterLayout = uix.Grid( ...
                'Parent', converterBox, ...
                'Spacing', 7);
            
            Label( ...
                'Parent', converterLayout, ...
                'String', 'Volts');
            
            obj.makePhotoreceptorLabels(converterLayout);
            
            obj.voltsBox = uicontrol( ...
                'Parent', converterLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Callback', @obj.onVoltsBox);
            
            obj.photoreceptorBoxes = ...
                obj.makePhotoreceptorBoxes(converterLayout);
            
            set(converterLayout, ...
                'Widths', [80 -1 22], ...
                'Heights', 23 * ones(1, obj.photoreceptors.length + 1));
            
            set(mainLayout, ...
                'Heights', [155 -1]);
        end
        
        function makePhotoreceptorLabels(obj, parent)
            import appbox.*;
            import symphonyui.app.App;
            for p = 1:obj.photoreceptors.length
                label_string = ...
                    obj.presentablePhotoreceptorStrings(obj.orderedPhotoreceptorKeys{p});
                Label( ...
                    'Parent', parent, ...
                    'String', [label_string ' R*/s']);
            end
        end
        
        function boxes = makePhotoreceptorBoxes(obj, parent)
            boxes = containers.Map();
            for p = 1:obj.photoreceptors.length
                boxes(obj.orderedPhotoreceptorKeys{p}) = uicontrol( ...
                    'Parent', parent, ...
                    'Style', 'edit', ...
                    'HorizontalAlignment', 'left', ...
                    'Callback', {@obj.onPhotoreceptorBox, obj.orderedPhotoreceptorKeys{p}});
            end
        end
        
        function orderedKeys = orderPhotoreceptorKeys(obj)
            keys = obj.photoreceptors.keys();
            % check for 'rod'
            idx = [];
            for i = 1:numel(keys)
                if strcmpi(keys{i}, 'rod')
                    idx = i;
                    break
                end
            end
            if isempty(idx)
                orderedKeys = sort(keys);
            else
                orderedKeys = [keys{idx} sort(keys((1:numel(keys)) ~= idx))];
            end
        end
    end
    
    methods (Access = protected)
        
        function willGo(obj)
            obj.actuallyCreateUI();
            
            obj.leds = obj.configurationService.getDevices('LED');
            
            obj.populateLedList();
            obj.populateNdfs();
            obj.populateGain();
            obj.populateSpecies();
            if ~obj.isSufficientInformation()
                obj.toggleBottomHalf('off');
            end
        end
        
        function bind(obj)
            bind@symphonyui.ui.Module(obj);
            
            obj.bindLeds();
            
            d = obj.documentationService;
            obj.addListener(d, 'BeganEpochGroup', @obj.onServiceBeganEpochGroup);
            obj.addListener(d, 'EndedEpochGroup', @obj.onServiceEndedEpochGroup);
            obj.addListener(d, 'ClosedFile', @obj.onServiceClosedFile);
            
            c = obj.configurationService;
            obj.addListener(c, 'InitializedRig', @obj.onServiceInitializedRig);
        end
        
    end
    
    methods (Access = private)
        
        function bindLeds(obj)
            for i = 1:numel(obj.leds)
                obj.ledListeners{end + 1} = obj.addListener(obj.leds{i}, 'SetConfigurationSetting', @obj.onLedSetConfigurationSetting);
            end
        end
        
        function unbindLeds(obj)
            while ~isempty(obj.ledListeners)
                obj.removeListener(obj.ledListeners{1});
                obj.ledListeners(1) = [];
            end
        end
        
        function populateLedList(obj)
            names = cell(1, numel(obj.leds));
            for i = 1:numel(obj.leds)
                names{i} = obj.leds{i}.name;
            end
            
            if numel(obj.leds) > 0
                set(obj.ledPopupMenu, 'String', names);
                set(obj.ledPopupMenu, 'Values', obj.leds);
            else
                set(obj.ledPopupMenu, 'String', {' '});
                set(obj.ledPopupMenu, 'Values', {[]});
            end
            set(obj.ledPopupMenu, 'Enable', appbox.onOff(numel(obj.leds) > 0));
        end
        
        function onSelectedLed(obj, ~, ~)
            obj.populateNdfs();
            obj.populateGain();
            obj.onVoltsBox(obj.voltsBox, []);
        end
        
        function onSelectedLedHelp(obj, ~, ~)
            msg = 'Select the LED for which to perform isomerizations conversions.  The LEDs in this dropdown came from the current rig configuration.';
            obj.view.showMessage(msg);
        end
        
        function populateNdfs(obj)
            led = get(obj.ledPopupMenu, 'Value');
            if isempty(led)
                set(obj.ndfsField, 'String', '');
            else
                ndfs = led.getConfigurationSetting('ndfs');
                set(obj.ndfsField, 'String', strjoin(ndfs, '; '));
            end
        end
        
        function onSelectedNdfsHelp(obj, ~, ~)
            msg = 'This field is auto-populated.  The values are taken from the values provided for the given LED in the ''Configure Devices'' section of the Data Manager.';
            obj.view.showMessage(msg);
        end
        
        function populateGain(obj)
            led = get(obj.ledPopupMenu, 'Value');
            if isempty(led)
                set(obj.gainField, 'String', '');
            else
                gain = led.getConfigurationSetting('gain');
                set(obj.gainField, 'String', gain);
            end
        end
        
        function onSelectedGainHelp(obj, ~, ~)
            msg = 'This field is auto-populated.  The values are taken from the values provided for the given LED in the ''Configure Devices'' section of the Data Manager.';
            obj.view.showMessage(msg);
        end
        
        function populateSpecies(obj)
            if isempty(obj.species)
                set(obj.speciesField, 'String', '');
            else
                set(obj.speciesField, 'String', obj.species.label);
            end
        end
        
        function s = findSpecies(obj)
            s = [];
            
            if ~obj.documentationService.hasOpenFile()
                return;
            end
            
            group = obj.documentationService.getCurrentEpochGroup();
            if isempty(group)
                return;
            end
            
            source = group.source;
            while ~isempty(source) && ~any(strcmp(source.getResourceNames(), 'photoreceptors'))
                source = source.parent;
            end
            s = source;
        end
        
        function p = findPhotoreceptors(obj)
            p = obj.species.getResource('photoreceptors');
        end
        
        function onSelectedSpeciesHelp(obj, ~, ~)
            msg = 'The species is auto-populated based on the species specified within the source of the current epoch group.  This will dictate which photoreceptors are listed below';
            obj.view.showMessage(msg);
        end
        
        function onServiceBeganEpochGroup(obj, ~, ~)
            obj.species = obj.findSpecies();
            obj.populateSpecies();
            obj.populatePhotoreceptorList();
            obj.updateBottomHalf();
        end
        
        function onServiceEndedEpochGroup(obj, ~, ~)
            obj.species = obj.findSpecies();
            obj.populateSpecies();
            obj.populatePhotoreceptorList();
        end
        
        function onServiceClosedFile(obj, ~, ~)
            obj.species = [];
            obj.populateSpecies();
        end
        
        function onServiceInitializedRig(obj, ~, ~)
            obj.unbindLeds();
            obj.leds = obj.configurationService.getDevices('LED');
            obj.populateLedList();
            obj.bindLeds();
        end
        
        function onLedSetConfigurationSetting(obj, ~, ~)
            obj.populateNdfs();
            obj.populateGain();
        end
        
        % converter updates
        function onVoltsBox(obj, hObj, ~)
            import edu.washington.riekelab.mardoum.modules.IsomerizationsConverterUtilities.*
            % update the isomerizations count with the new voltage for each
            % photoreceptor
            voltage = str2double(hObj.String);
            
            led = get(obj.ledPopupMenu, 'Value');
            deviceSpectrum = led.getResource('spectrum');
            deviceCalibration = led.getResource('calibrations');
            deviceCalibration = deviceCalibration(obj.gainField.String);
            ndfAttenuations = led.getResource('ndfAttenuations');
            
            for k = 1:obj.photoreceptors.length
                
                key = obj.orderedPhotoreceptorKeys{k};
                curr_isom = ...
                    SymphonyIsomerizationsConverter( ...
                    deviceCalibration, ...
                    deviceSpectrum, ...
                    obj.photoreceptors(key).spectrum, ...
                    obj.photoreceptors(key).collectingArea, ...
                    obj.ndfsField.String, ...
                    ndfAttenuations, ...
                    'voltstoisom', ...
                    voltage);
                
                curr_isom = round(curr_isom);
                currBox = obj.photoreceptorBoxes(key);
                currBox.String = num2str(curr_isom);
                currBox.Value = curr_isom;
            end
        end
        
        function onPhotoreceptorBox(obj, hObj, ~, photoreceptor_key)
            import edu.washington.riekelab.mardoum.modules.IsomerizationsConverterUtilities.*
            
            % get the device info (for currently selected LED)
            led = get(obj.ledPopupMenu, 'Value');
            deviceSpectrum = led.getResource('spectrum');
            deviceCalibration = led.getResource('calibrations');
            deviceCalibration = deviceCalibration(obj.gainField.String);
            ndfAttenuations = led.getResource('ndfAttenuations');
            
            % start by figuring out the voltage
            isomerizations = str2double(hObj.String);
            volts = ...
                SymphonyIsomerizationsConverter( ...
                deviceCalibration, ...
                deviceSpectrum, ...
                obj.photoreceptors(photoreceptor_key).spectrum, ...
                obj.photoreceptors(photoreceptor_key).collectingArea, ...
                obj.ndfsField.String, ...
                ndfAttenuations, ...
                'isomtovolts', ...
                isomerizations);
            
            % update the volts box
            obj.voltsBox.String = num2str(volts);
            obj.voltsBox.Value = volts;
            
            % loop through the rest of the photoreceptors and update their
            % isomerization counts
            for k = 1:obj.photoreceptors.length
                key = obj.orderedPhotoreceptorKeys{k};
                if ~strcmp(key, photoreceptor_key)
                    curr_isom = ...
                        SymphonyIsomerizationsConverter( ...
                        deviceCalibration, ...
                        deviceSpectrum, ...
                        obj.photoreceptors(key).spectrum, ...
                        obj.photoreceptors(key).collectingArea, ...
                        obj.ndfsField.String, ...
                        ndfAttenuations, ...
                        'voltstoisom', ...
                        volts);
                    
                    curr_isom = round(curr_isom);
                    currBox = obj.photoreceptorBoxes(key);
                    currBox.String = num2str(curr_isom);
                    currBox.Value = curr_isom;
                end
            end
        end
        
        % state should be 'on' or 'off'
        function toggleBottomHalf(obj, state)
           obj.voltsBox.Enable = state;
           keys = obj.photoreceptorBoxes.keys();
           for i = 1:numel(keys)
              box = obj.photoreceptorBoxes(keys{i}); 
              box.Enable = state;
           end
        end
        
        function tf = isSufficientInformation(obj)
            tf = true;
        end
        
        function updateBottomHalf(obj)
            if obj.isSufficientInformation()
                obj.toggleBottomHalf('on');
            else
                obj.toggleBottomHalf('off');
            end
        end
                
            
    end
    
    methods (Static)
        function value = presentablePhotoreceptorStrings(value)
            switch value
                case {'scone', 'sCone'}
                    value = 'S Cone';
                case {'mcone', 'mCone'}
                    value = 'M Cone';
                case {'lcone', 'lCone'}
                    value = 'L cone';
                case 'rod'
                    value = 'Rod';
            end
        end
    end
end