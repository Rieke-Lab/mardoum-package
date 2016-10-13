classdef Calibrator < symphonyui.ui.Module
    
    properties
        % this is a structure that contains handles for many of the ui
        % elements
        ui
        
        % a cell array of Symphony 2.0 device objects
        devices
        
        % java hash maps of hash maps that contain the most recent
        % calibration values and dates (as strings), respectively for all
        % of the devices/settings on the current rig; the first hash maps
        % have device names as keys, and their values (themselves maps)
        % have setting/gain names as keys
        recentCalibrationValues
        recentCalibrationDates
        
        % this is a string that contains the root folder for the
        % calibration data - can vary based on the given rig
        calibrationFolderPath
    end
    
    properties (Access = private)
        % this will be a structure with the fields: 'device' and 'setting',
        % each of these will contain an index that will specify which
        % device/setting pair is currently selected (this will allow the ui
        % to make sure that the selection has actually changed when an
        % option in the box is clicked before it changes the right half of
        % the ui)
        currentSelection
        
        % some T/F values that will be used to provide context for ui
        % callbacks
        ledOn
        inputPanelVisible
        
        
        % this will be a cell array with an element for each device; each
        % of these elements themselves will be an array of trues or falses
        % that will specify if a given setting for a given device has been
        % calibrated (0 for no, 1 for yes)
        calibratedTFs
        
        % This will be a cell array of maps that will store all of the new
        % calibration values as they are entered.  They keys will be the
        % setting names and the values will be the calibration values.
        calibrationValues
        
        % will hold the names for each of the devices/settings on the rig,
        % or the name of the rig itself
        deviceNames % cell array of device names - indeces match obj.devices; modified as devices calibrated
        settingsNames % cell array of cell arrays (one per device), first indexing matches obj.devices
        settingsDisplayNames % starts identical to settingsNames, but modified as devices calibrated
        rigName % string of rig name
        
    end
    
    % Properties related to the calibration history viewer.
    properties
        % stores the calibration history viewer object
        calibrationHistoryViewer = []
    end
    
    properties (Dependent)
        numDevices % number of elements in obj.devices
        deviceSelection % index of selected device
        settingSelection % index of selected setting/gain
        requestedDeviceSignal % entry in voltage/signal box
        skipString % string about skipping that includes device/setting names
        lastCalibrationDate % string of date of most recent calibration for selected device
        inputBoxTitleString % string for title that includes device/setting names
        deviceName % string of name of current device
        settingName % string of name of current setting
    end
    
    % default values
    properties
        defaultEditBoxColor = [0.94 0.94 0.94]
        
        % if a submitted calibration is sufficiently different than the
        % most recent calibration value, the user will be given a warning -
        % this property will set the threshold for when this warning is
        % generated = it will be in units of fraction of the old value
        % tolerated as a difference
        warningLargeChangeThreshold = 0.1 % tolerate 10% change
        
        % whether or not anything has been implemented for advanced
        % settings
        advancedSettingsFunctional = false;
    end
    
    % Create the UI
    methods
                    % this method is called to create the UI, but the module does
            % not have access at this time to all of the information it
            % needs to complete the UI, but as it receives this, things
            % will be populated
        function createUi(obj, figureHandle)
            % import symphonyui.ui.util.*;
            import appbox.*;
            
            set(figureHandle, ...
                'Name', 'Calibrator', ...
                'Position', screenCenter(585, 335));
            
            mainLayout = uix.HBox( ...
                'Parent', figureHandle, ...
                'Padding', 11, ...
                'Spacing', 11);
            
            obj.ui.leftLayout = uix.VBox(...
                'Parent', mainLayout, ...
                'Spacing', 0);
            
            obj.ui.listsLayout = uix.HBox(...
                'Parent', obj.ui.leftLayout, ...
                'Spacing', 11);
            
            
            % make a layout that will hold the button for viewing the
            % advanced settings
            uix.Empty('Parent', obj.ui.leftLayout); %#ok<*PROP>
            obj.ui.advancedButton.layout = uix.HBox(...
                'Parent', obj.ui.leftLayout);
            uix.Empty('Parent', obj.ui.advancedButton.layout);
            obj.ui.advancedButton.button = uicontrol(...
                'Parent', obj.ui.advancedButton.layout, ...
                'Style', 'pushbutton', ...
                'String', 'Advanced', ...
                'Callback', @obj.advancedSettingsCallback);
            uix.Empty('Parent', obj.ui.advancedButton.layout);
            set(obj.ui.advancedButton.layout, 'Widths', [-1 -2 -1]);
            
            % make a layout that will hold the button for viewing the
            % calibration history
            uix.Empty('Parent', obj.ui.leftLayout);
            obj.ui.historyButton.layout = uix.HBox(...
                'Parent', obj.ui.leftLayout);
            uix.Empty('Parent', obj.ui.historyButton.layout);
            obj.ui.historyButton.button = uicontrol(...
                'Parent', obj.ui.historyButton.layout, ...
                'Style', 'pushbutton', ...
                'String', 'View History', ...
                'Callback', @obj.viewCalibrationHistoryCallback);
            uix.Empty('Parent', obj.ui.historyButton.layout);
            set(obj.ui.historyButton.layout, 'Widths', [-1 -2 -1]);
            
            % make the layout that will either hold the string instructing
            % the user to calibrate all devices, or the final submit
            % button; also make an empty space above it
            uix.Empty('Parent', obj.ui.leftLayout);
            obj.ui.instructionsSubmitLayout.layout = uix.HBox(...
                'Parent', obj.ui.leftLayout);
            uix.Empty('Parent', obj.ui.instructionsSubmitLayout.layout);
            instr = 'Please provide calibration values for all settings on all devices.';
            obj.ui.instructionsSubmitLayout.uiElement = uicontrol(...
                'Parent', obj.ui.instructionsSubmitLayout.layout, ...
                'Style', 'text', ...
                'String', instr, ...
                'FontSize', 10);
            uix.Empty('Parent', obj.ui.instructionsSubmitLayout.layout);
            set(obj.ui.instructionsSubmitLayout.layout, 'Widths', [1 -1 1]);
            
            % set left layout spacing
            set(obj.ui.leftLayout, 'Heights', [-1 7 28 5 28 5 33]);
            
            obj.ui.deviceList.layout = uix.VBox( ...
                'Parent', obj.ui.listsLayout, ...
                'Spacing', 7);
            
            obj.ui.deviceSettings.layout = uix.VBox( ...
                'Parent', obj.ui.listsLayout, ...
                'Spacing', 7);
            
            obj.ui.deviceList.title = uicontrol( ...
                'Parent', obj.ui.deviceList.layout, ...
                'Style', 'Text', ...
                'String', 'Select Device', ...
                'FontSize', 12);
            obj.ui.deviceList.box = uicontrol( ...
                'Parent', obj.ui.deviceList.layout, ...
                'Style', 'listbox', ...
                'Callback', @obj.deviceBoxClicked);
            
            obj.ui.deviceSettings.title = uicontrol( ...
                'Parent', obj.ui.deviceSettings.layout, ...
                'Style', 'Text', ...
                'String', 'Select Setting', ...
                'FontSize', 12);
            obj.ui.deviceSettings.box = uicontrol( ...
                'Parent', obj.ui.deviceSettings.layout, ...
                'Style', 'listbox', ...
                'Callback', @obj.settingsBoxClicked);
            
            set(obj.ui.deviceList.layout, ...
                'Heights', [25, -1]);
            set(obj.ui.deviceSettings.layout, ...
                'Heights', [25 -1]);
            
            % create the panel that will store all of the ui components
            % related to calibration input
            obj.ui.calibrationPanel.layout = uix.VBox( ...
                'Parent', mainLayout,...
                'Spacing', 7);
            
            set(mainLayout, ...
                'Widths', [-24 -30]);
            
            % set the default values for the 'currentSelection'
            obj.currentSelection.device = 1;
            obj.currentSelection.setting = 1;
            
            % set the default values for the TF values used to provide
            % context to the callbacks for the ui elements
            obj.ledOn = false;
            obj.inputPanelVisible = false;
            
        end
    end
    
    % Initialize things
    methods (Access = protected)
        
        % this method will populate the UI elements as well as retrieve
        % and store all of the information needed regarding the
        % devices, their settings, recent calibrations, etc.
        function willGo(obj)
            obj.calibrationFolderPath =  obj.getCalibrationFolderPath();
            
            % get the devices, and also figure out associated names
            obj.createDeviceList();
            obj.deviceNames = obj.getDeviceNames();
            obj.settingsNames = obj.getSettingsNames();
            obj.settingsDisplayNames = obj.settingsNames;
            obj.rigName = obj.getRigName(); % requires obj.calibrationFolderPath
            
            % get the most recent calibration values
            obj.getMostRecentCalibrations()
            
            % add the device names to the device list box
            obj.populateDeviceBox;
            
            % call the callback for the device box (because this is what
            % populates the settings box and calling it will populate it
            % for the first time)
            obj.populateSettingsList(get(obj.ui.deviceList.box, 'Value'));
            
            % create the stuff for the calibration input half of the ui
            obj.createInputBox;
            
            % make the cell array of TF values denoting if given
            % device/setting combinations have been calibrated, also
            % make the cell array to store calibration values
            obj.calibratedTFs = cell(1,obj.numDevices);
            obj.calibrationValues = cell(1,obj.numDevices);
            % obj.newCalibrationValues = cell(1,obj.numDevices);
            for dev = 1:obj.numDevices
                settingsForThisDevice = numel(obj.settingsNames{dev});
                obj.calibratedTFs{dev} = false(1, settingsForThisDevice);
                obj.calibrationValues{dev} = containers.Map();
                
            end
        end
        
        % creates and stores a cell array containing each of the
        % device objects to be calibrated; it searches through all devices
        % on the current rig and includes those in which the string 'LED
        % (not case sensitive) appears in the name; the cell array is
        % stored as obj.devices
        function createDeviceList(obj)
            devices = obj.configurationService.getDevices();
            num = numel(devices);
            use = false(1,num);

            for dv = 1:num
                use(dv) = sum(regexpi(devices{dv}.name, 'LED'));
            end

            obj.devices = devices(logical(use));           
        end
        
        % returns a string of the base folder containing calibration data
        function folderPath = getCalibrationFolderPath(obj) %#ok<MANU>
            folderPath = ...
                edu.washington.riekelab.mardoum.modules.CalibratorUtilities.CalibratorConstants.PATH;
        end
        
        % returns rig name as a string - gets it from the last directory in
        % the calibration folder path
        function name = getRigName(obj)
            folders = strsplit(obj.calibrationFolderPath);
            name = folders{end};
        end
        
        % returns a cell array of device names
        function names = getDeviceNames(obj)
            names = cell(1, obj.numDevices);
            for i = 1:obj.numDevices
                names{i} = obj.devices{i}.name;
            end
        end
        
        % returns a cell array with an element for each device; each of
        % these elements themselves are cell arrays that contain a string
        % for each setting/gain for the given device; indexing of the outer
        % cell array is identical to that in obj.devices/obj.deviceNames
        function settings = getSettingsNames(obj)
            settings = cell(1, obj.numDevices);
            for dev = 1:obj.numDevices
                % get the configurationSettingDescriptors from the device
                % object - one of them will be for the settings/gain
                descriptors = ...
                    obj.devices{dev}.getConfigurationSettingDescriptors();
                % find which one is for the settings/gain
                idx = 1;
                gain = descriptors(idx);
                while ~strcmp(gain.name, 'gain')
                    idx = idx + 1;
                    gain = descriptors(idx);
                end
                % the actual strings for the settings are stored in
                % .type.domain - place these in the cell array
                gains = gain.type.domain;
                settings{dev} = gains(2:end);
            end
        end
             
        % adds device names as 'String' property of the uielement for the
        % device list
        function populateDeviceBox(obj)
            set(obj.ui.deviceList.box, 'String', obj.deviceNames);
        end
        
        % populates settings list based on the index provided - this index
        % will be used to choose which settings list to use from
        % obj.settingsDisplayNames
        function populateSettingsList(obj, idx)
            obj.ui.deviceSettings.box.String = obj.settingsDisplayNames{idx};
        end
        
        % get the most recent calibration values and dates; store them in
        % Java HashMaps; these will be stored in
        % obj.recentCalibrationValues and obj.recentCalibrationDates; each
        % will be a map that contains maps; the outer map will be indexed
        % by device names; the inner map will be indexed by settings names
        % for the given device
        function getMostRecentCalibrations(obj)
            % make the outer maps
            obj.recentCalibrationValues = java.util.HashMap();
            obj.recentCalibrationDates = java.util.HashMap();
            for i = 1:obj.numDevices
                devName = obj.devices{i}.name;
                % make the inner maps
                obj.recentCalibrationValues.put(devName, java.util.HashMap());
                obj.recentCalibrationDates.put(devName, java.util.HashMap());
                for j = 1:numel(obj.settingsNames{i})
                    % get folder for calibrations for the device/setting
                    setName = obj.settingsNames{i}{j};
                    filePath = [obj.calibrationFolderPath filesep ...
                        devName filesep ...
                        setName '.txt'];
                    % find most recent entry in that file
                    [val, date] = ...
                        edu.washington.riekelab.mardoum.modules.CalibratorUtilities.readMostRecentCalibration(filePath);
                    % add to map
                    obj.recentCalibrationValues.get(devName).put(setName, val);
                    obj.recentCalibrationDates.get(devName).put(setName, char(date));
                end
            end
        end
        
        % populates the input box with appropriate uielements
        function createInputBox(obj)
            % import symphonyui.ui.util.*;
            import appbox.*;
          
            % store things as variables within the function for convenience
            calibrationPanel.layout = obj.ui.calibrationPanel.layout;
            mainLayout = calibrationPanel.layout;
            
            % make a title for the entire panel
            calibrationPanel.panelTitle = uicontrol(...
                'Parent', mainLayout, ...
                'Style', 'text', ...
                'String', obj.inputBoxTitleString, ...
                'FontSize', 12);
            
            % add a title string for calibration section
            calibrationPanel.calibrationTitle = uicontrol(...
                'Parent', mainLayout,...
                'Style', 'text', ...
                'String', 'Perform New Calibration', ...
                'FontSize', 10, ...
                'FontWeight', 'bold');
            
            
            % add horizontal box for 'Calibrate using' string and a box to
            % enter voltage/input
            calibrationPanel.signalEntryRow.layout = uix.HBox(...
                'Parent', mainLayout);
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.signalEntryRow.layout);
            % add a string that labels the box for voltage/input entry
            calibrationPanel.signalEntryRow.label = Label(...
                'Parent', calibrationPanel.signalEntryRow.layout, ...
                'String', 'Calibrate using (V):');
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.signalEntryRow.layout);
            % add a box for the user to enter a voltage/input
            calibrationPanel.signalEntryRow.inputBox = uicontrol(...
                'Parent', calibrationPanel.signalEntryRow.layout, ...
                'Style', 'edit', ...
                'String', '1');
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.signalEntryRow.layout);
            % adjust the widths
            set(calibrationPanel.signalEntryRow.layout, 'Widths', [-15 -40 -5 -28 -12]);
            
            
            % add a horizontal box for the buttons to turn the device on or
            % off
            calibrationPanel.onOffButtons.layout = uix.HBox(...
                'Parent', mainLayout);
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.onOffButtons.layout);
            % make an on button
            calibrationPanel.onOffButtons.onButton = uicontrol(...
                'Parent', calibrationPanel.onOffButtons.layout, ...
                'Style', 'pushbutton', ...
                'String', 'Turn LED on', ...
                'FontSize', 8, ...
                'Callback', @obj.onButtonCallback);
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.onOffButtons.layout);
            % make an off button
            calibrationPanel.onOffButtons.offButton = uicontrol(...
                'Parent', calibrationPanel.onOffButtons.layout, ...
                'Style', 'pushbutton', ...
                'String', 'Turn LED off', ...
                'FontSize', 8, ...
                'Callback', @obj.offButtonCallback);
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.onOffButtons.layout);
            % adjust the widths
            set(calibrationPanel.onOffButtons.layout, 'Widths', [-27 -28 -5 -28 -12]);
            
            
            % add a horizontal box for an input box for the user to enter
            % the power reading as well as a label for the box
            calibrationPanel.powerEntry.layout = uix.HBox(...
                'Parent', mainLayout, ...
                'Visible', 'off');
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.powerEntry.layout);
            % make a string to label the input box
            calibrationPanel.powerEntry.label = Label(...
                'Parent', calibrationPanel.powerEntry.layout, ...
                'String', 'Power (nW)');
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.powerEntry.layout);
            % make the input box
            calibrationPanel.powerEntry.inputBox = uicontrol(...
                'Parent', calibrationPanel.powerEntry.layout, ...
                'Style', 'edit');
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.powerEntry.layout);
            % control widths
            set(calibrationPanel.powerEntry.layout, 'Widths', [-31 -24 -5 -28 -12]);
            
            
            % add a horizontal box for an input box for thte user to enter
            % the spot size as well as a label for the box
            calibrationPanel.spotSizeEntry.layout = uix.HBox(...
                'Parent', mainLayout, ...
                'Visible', 'off');
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.spotSizeEntry.layout);
            % make a string to label the input box
            calibrationPanel.spotSizeEntry.label = Label(...
                'Parent', calibrationPanel.spotSizeEntry.layout, ...
                'String', 'Spot diam. (um)');
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.spotSizeEntry.layout);
            % make the input box
            calibrationPanel.spotSizeEntry.inputBox = uicontrol(...
                'Parent', calibrationPanel.spotSizeEntry.layout, ...
                'Style', 'edit');
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.spotSizeEntry.layout);
            % control widths
            set(calibrationPanel.spotSizeEntry.layout, 'Widths', [-20 -35 -5 -28 -12]);

            
            % make a row for the submit and change voltage buttons
            calibrationPanel.submitChangeButtons.layout = uix.HBox(...
                'Parent', mainLayout, ...
                'Visible', 'off');
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.submitChangeButtons.layout);
            % make a change voltage button
            calibrationPanel.submitChangeButtons.changeButton = uicontrol(...
                'Parent', calibrationPanel.submitChangeButtons.layout, ...
                'Style', 'pushbutton', ...
                'String', 'New voltage', ...
                'FontSize', 8, ...
                'Callback', @obj.changeVoltageButtonCallback);
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.submitChangeButtons.layout);
            % make a submit values button
            calibrationPanel.submitChangeButtons.submitButton = uicontrol(...
                'Parent', calibrationPanel.submitChangeButtons.layout, ...
                'Style', 'pushbutton', ...
                'String', 'Submit', ...
                'FontSize', 8, ...
                'Callback', @obj.inputPanelSubmitCallback);
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.submitChangeButtons.layout);
            % adjust the widths
            set(calibrationPanel.submitChangeButtons.layout, 'Widths', [-27 -28 -5 -28 -12]);
            
            
            % make a title string for the skip calibrating section
            calibrationPanel.skipTitle = uicontrol(...
                'Parent', mainLayout, ...
                'Style', 'text', ...
                'String', obj.skipString, ...
                'FontSize', 10, ...
                'FontWeight', 'bold');
            

            % make a box for the string that says the last calibration
            % value as well as a button that says to use that value
            calibrationPanel.skipButton.layout = uix.HBox(...
                'Parent', mainLayout);
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.skipButton.layout);
            % make a string that shows the last calibration value
            str = ['Last Calibration: ' obj.lastCalibrationDate];
            calibrationPanel.skipButton.label = Label(...
                'Parent', calibrationPanel.skipButton.layout, ...
                'String', str);
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.skipButton.layout);
            % add the button
            calibrationPanel.skipButton.button = uicontrol(...
                'Parent', calibrationPanel.skipButton.layout, ...
                'Style', 'pushbutton', ...
                'String', 'Use This', ...
                'FontSize', 9, ...
                'Callback', @obj.useOldCalibrationCallback);
            % add an empty space to help with appropriate spacing
            uix.Empty('Parent', calibrationPanel.skipButton.layout);
            set(calibrationPanel.skipButton.layout, 'Widths', [-6 -49 -5 -28 -12]);

            
            % adjust main layout sizes
            set(mainLayout, 'Heights', [25, -2, -4, -4, -4, -4, -4, -2, -4]);
            
            % store the calibration panel structure
            obj.ui.calibrationPanel.layout = mainLayout;
            obj.ui.calibrationPanel = calibrationPanel;
        end     
    end
    
    % Methods for changing or keeping tabs on the UI
    methods
        % when an LED/device is turned on, the background color for the
        % editable text box where a voltage/signal is specified will
        % become a different color - this will figure out what color to
        % use based on the LED      
        function color = determineOnColor(obj)
            name = char(obj.devices{obj.currentSelection.device}.name);
            
            if regexpi(name, 'red')
                color = [1 0 0.2];
            elseif regexpi(name, 'blue')
                color = [0 0.8 1];
            elseif regexpi(name, 'green')
                color = [0 1 0.2];
            elseif regexpi(name, 'uv')
                color = [0.8 0.6 1];
            else
                color = [1 1 0.4];
            end  
        end
        
        % this will update the values stored for the current selection
        function updateCurrentSelectionValue(obj)            
            obj.currentSelection.device = ...
                get(obj.ui.deviceList.box, 'Value');
            obj.currentSelection.setting = ...
                get(obj.ui.deviceSettings.box, 'Value');
        end
        
        % will look at the user inputs for spot size and power and
        % determine if they are acceptable; they must both be positive
        % numbers
        function value = inputsAcceptable(obj)
            power = ...
                str2double(get(obj.ui.calibrationPanel.powerEntry.inputBox, 'String'));
            spotSize = ...
                str2double(get(obj.ui.calibrationPanel.spotSizeEntry.inputBox, 'String'));
            
            % str2double will return NaN if the entries in the boxes are
            % not numbers
            if isnan(power) || isnan(spotSize)
                value = false;
            else
                % make sure they are both positive values
                if power > 0 && spotSize > 0
                    value = true;
                else
                    value = false;
                end
            end
        end
        
        % will determine if device has been calibrated; if so, will ask
        % user if they want to overwrite the value; will return boolean
        % based on user's response
        function value = useValue(obj)
            % start by making sure this device has not already been
            % calibrated
            if obj.calibratedTFs{obj.currentSelection.device}(obj.currentSelection.setting)
                % it has already been calibrated, ask about overwrite
                str = ['A calibration value for this device has already been provided today. '...
                    'Would you like to overwrite that value?'];
                choice = questdlg(str, 'Overwrite?', 'Yes', 'No', 'No');
                if strcmp(choice, 'Yes')
                    value = true;
                else
                    value = false;
                end
            else
                value = true;
            end
        end
        
        % compares new calibration value to most recent; returns a boolean
        % for whether or not the difference exceeds the threshold defined
        % in obj.warningLargeChangeThreshold; also returns the percent
        function [TF, percent] = tooDifferentFromLastCalibrationValue(obj, newValue, device, setting)
            oldValue = ...
                obj.recentCalibrationValues.get(obj.devices{device}.name).get(obj.settingsNames{device}{setting});
            
            fractionDiff = (newValue - oldValue)/oldValue;
            
            if fractionDiff > obj.warningLargeChangeThreshold
                TF = true;
            else
                TF = false;
            end

            percent = fractionDiff * 100;
            percent = round(10 * percent) / 10;
        end
        
        % when user clicks within listbox, callback will be called to
        % update entry half of ui window for newly selected device; this
        % will be used to first make sure that they didn't just click on
        % the already selected device; returns a boolean; true if a new
        % device was selected, false otherwise
        function value = didSelectionChange(obj)
            if obj.deviceSelection == obj.currentSelection.device
                if obj.settingSelection == obj.currentSelection.setting
                    value = false;
                else
                    value = true;
                end
            else
                value = true;
            end           
        end
 
        % once values have been provided for all devices (either by
        % providing new calibration values or selecting to use the most
        % recent value), this will add a submit button to will allow the
        % entire set of calibration values to be submitted
        function makeFinalSubmitButton(obj) 
            % there is a UI element in the location that will eventually
            % store the submit button; currently that UI element is just a
            % string instructing the user to calibrate all settings for all
            % devices; switch that ui element to a pushbutton
            set(obj.ui.instructionsSubmitLayout.uiElement, ...
                'Style', 'pushbutton', ...
                'String', 'SUBMIT CALIBRATIONS', ...
                'FontWeight', 'bold', ...
                'Callback', @obj.submitAllCalibrationsButton);
            
            set(obj.ui.instructionsSubmitLayout.layout, 'Widths', [-1 -6 -1]);       
        end

        % this will close the UI when calibration is complete
        % use the superclass method
        function closeUI(obj)
            obj.delete;
        end
        
        % moves the current selection to the next possible selection; if
        % there are additional settings for the selected device, it will
        % move to those, and if not, it will move to a new device; if all
        % devices have been calibrated, it will call the method to make a
        % final submit button
        function moveToNext(obj)            
            % first, make sure that all of the devices have not been
            % calibrated, if they have, allow the user to submit, if not,
            % move to the next device
            allCalibrated = true;
            dev = 0;
            while allCalibrated && obj.numDevices > dev
                dev = dev + 1;
                if sum(obj.calibratedTFs{dev} == false)
                    allCalibrated = false;
                end
            end
            
            if allCalibrated               
                % turn the current device off, and make final submit button
                obj.turnOffSelectedDevice;               
                obj.makeFinalSubmitButton
            else                
                % check to see if there are any settings for the current
                % device that have not been calibrated
                if sum(obj.calibratedTFs{obj.currentSelection.device} == false);
                    % there are some that have yet to be calibrated; find the
                    % first
                    found = false;
                    nextSetting = 0;
                    while found == false
                        nextSetting = nextSetting + 1;
                        if obj.calibratedTFs{obj.currentSelection.device}(nextSetting) == false
                            found = true;
                        end
                    end
                    
                    % since a setting was found that still needs calibrating
                    % for this device, the device doesn't need to change
                    nextDevice = obj.currentSelection.device;
                else
                    % all of the settings for the current device have been
                    % calibrated, first see if there were any settings skipped
                    % on previous devices
                    found = false;
                    nextDevice = 0;
                    while ~found
                        nextDevice = nextDevice + 1;
                        if nextDevice ~= obj.currentSelection.device
                            nextSetting = 0;
                            while ~found && nextSetting < numel(obj.calibratedTFs{nextDevice})
                                nextSetting = nextSetting + 1;
                                if ~obj.calibratedTFs{nextDevice}(nextSetting)
                                    found = true;
                                end
                            end
                        end
                    end
                end
                
                % now that the appropriate next device and setting have
                % been determined, move the ui to those devices and call
                % the callbacks for changing of those selections
                set(obj.ui.deviceList.box, 'Value', nextDevice);
                obj.deviceBoxClicked();
                set(obj.ui.deviceSettings.box, 'Value', nextSetting);
                obj.settingsBoxClicked();
                
            end
            
        end
        
        % will make the entry for the given device/setting green and bold
        % in the listbox; will indicate that the given setting for that
        % device has been completed, or that the entire device has been
        % completed
        function markAsCompleted(obj, device, setting)
            % first check if the device has already been marked as completed
            if ~obj.calibratedTFs{device}(setting)
                % it has not been marked as completed (because the first
                % time a calibration value is provided for a device, the
                % calibratedTF value becomes true; but, this method is
                % called first - therefore, the only time it will be called
                % when this value is still false is the first time a
                % calibration value is provided for a device)
                obj.settingsDisplayNames{device}(setting) = ...
                    obj.makeColoredAndBold(obj.settingsNames{device}(setting));
                
                % refresh the settings list to show changes
                obj.populateSettingsList(device);
                
                % if this is the final setting that needed calibrating for
                % the given device, the device should also be marked as
                % completed; check for that here
                if sum(obj.calibratedTFs{device} == false) == 1
                    % this means there is only 1 left false - and based on
                    % statement above, it is know that it must be the
                    % current device/setting, so this device is complete
                    obj.deviceNames{device} = ...
                        obj.makeColoredAndBold(obj.deviceNames{device});
                    
                    % refresh device list to show changes
                    obj.populateDeviceBox;
                end 
            end            
        end
        
        % formats a string using html to make green and bold
        function str = makeColoredAndBold(obj, str) %#ok<INUSL>
            str = strcat('<html><font color="green"><b>', str);
        end
        
        % updates all of the appropriate values in the input box - can be
        % used when the selection changes
        function updateInputBox(obj)
            % update the input panel title
            set(obj.ui.calibrationPanel.panelTitle, 'String', obj.inputBoxTitleString);
            
            % update section on skipping calibration
            set(obj.ui.calibrationPanel.skipTitle, 'String', obj.skipString);
            
            % update last calibration date
            str = ['Last Calibration: ' obj.lastCalibrationDate];
            set(obj.ui.calibrationPanel.skipButton.label, 'String', str);
            
            % clear all windows, set input to default value of 1
            set(obj.ui.calibrationPanel.signalEntryRow.inputBox , 'String', '1');
            set(obj.ui.calibrationPanel.powerEntry.inputBox , 'String', '');
            set(obj.ui.calibrationPanel.spotSizeEntry.inputBox , 'String', '');
            
            % remove the input portion of the panel
            obj.changeInputPanelVisibility('off');
            
        end
        
        % toggles visibilitie of the input panel components; input
        % parameter 'newState' will be the string 'on' or the string 'off'
        % and method behavior will reflect that; also makes it so that when
        % the panel is visible, the user cannot change the voltage entry
        function changeInputPanelVisibility(obj, newState)
            % this function will change the visibility of the input panel
            
            set(obj.ui.calibrationPanel.powerEntry.layout, ...
                'Visible', newState);
            set(obj.ui.calibrationPanel.spotSizeEntry.layout, ...
                'Visible', newState);
            set(obj.ui.calibrationPanel.submitChangeButtons.layout, ...
                'Visible', newState);
                    
            if strcmp(newState, 'on')
                % change the TF value to reflect the change
                obj.inputPanelVisible = true;
                
                % disable the input window for voltage/signal - this is
                % important because it makes certain symphony knows the
                % voltage/input signal used to generate any reading the user
                % enters
                set(obj.ui.calibrationPanel.signalEntryRow.inputBox, 'enable', 'off');
                
            elseif strcmp(newState, 'off')
                % change the TF value to reflect the change
                obj.inputPanelVisible = false;
                
                % if the input panel is going away, the user should be able
                % to edit the signal used for calibration, reenable that ui
                % element
                set(obj.ui.calibrationPanel.signalEntryRow.inputBox, 'enable', 'on');
            end
        end
    end
    
    % UI callback methods
    methods
        % callback for when settings box clicked; confirms selection has
        % changed, and if so: shuts off previous device, updates which
        % setting is stored as currently selected, updates input panel, and
        % if using calibration history viewer, updates its current selection
        function settingsBoxClicked(obj,~,~)
            if obj.didSelectionChange()
                % if selection changed, shut off led
                obj.setDeviceToValue(obj.devices{obj.currentSelection.device}, 0);
                
                % since the setting changed, update what is stored as the
                % current selection
                obj.updateCurrentSelectionValue();
                
                % the calibration input component of the ui needs to be
                % updated to reflect the new selection
                obj.updateInputBox();
                
                if ~isempty(obj.calibrationHistoryViewer)
                    obj.showCurrentSelectionsCalibrationHistory;
                end
                
            end
        end
        
        % call back for when devices box clicked; confirms selection has
        % changed, and if so: shuts off previous device, updates settings
        % list and selection, updates which device is stored as currently
        % selected, updates the input panel, and if using history viewer,
        % updates its current selection
        function deviceBoxClicked(obj,~,~)
            if obj.didSelectionChange()
                % if device changed, shut off previous device
                obj.setDeviceToValue(obj.devices{obj.currentSelection.device}, 0);
                
                % if the device changed, the settings list needs to be
                % updated
                obj.populateSettingsList(get(obj.ui.deviceList.box, 'Value'));
                % select first setting
                set(obj.ui.deviceSettings.box, 'Value', 1);
                
                % since the setting changed, update what is stored as the
                % current selection (NOTE: this must be done after updating
                % the settings list, or else if will take whatever was the
                % selection from the old settings list)
                obj.updateCurrentSelectionValue();
                
                % the calibration input component of the ui needs to be
                % updated to reflect the new selection
                obj.updateInputBox();
                
                if ~isempty(obj.calibrationHistoryViewer)
                    obj.showCurrentSelectionsCalibrationHistory;
                end
                
            end
            
        end
        
        % callback for 'Turn LED on' button - turns on LED to requested
        % voltage, and if the input panel (for power/spot size) is not
        % visible, makes it visible
        function onButtonCallback(obj, ~, ~)
            obj.turnOnSelectedDevice(obj.requestedDeviceSignal)
            
            % if it is the first time the LED has been turned on, make the
            % input panel visible, otherwise do nothing more
            if ~obj.inputPanelVisible
                obj.changeInputPanelVisibility('on');
            end     
        end
        
        % callback for "Turn LED off' button - shuts off device
        function offButtonCallback(obj, ~, ~)
            obj.turnOffSelectedDevice;            
        end
        
        % callback for change voltage button; makes input panel invisible
        % (also allowing user to again change voltage balue); clears values
        % in spot size and power boxes, shuts off current device
        function changeVoltageButtonCallback(obj, ~, ~)            
            obj.changeInputPanelVisibility('off');
            
            % clear any entered values
            set(obj.ui.calibrationPanel.powerEntry.inputBox, 'String', '');
            set(obj.ui.calibrationPanel.spotSizeEntry.inputBox, 'String', '');

            obj.turnOffSelectedDevice;    
        end
        
        % callback for submit button user will use after submitting
        % calibration for given device/setting (not the final submit
        % button); checks acceptability of inputs, and if value should be
        % used (warns user about potential overwrite); if acceptable and to
        % be used, it calculates the calibration value (power / (spotSize *
        % voltage)) in (nW / (V * um^2), and checks if it is too different
        % from the most recent value (if so, user is warned); if all is
        % good, stores the value and moves to next device/setting; if the
        % user thinks new value is too different, clears inputs boxes and
        % doesnt save; also, if inputs are just not acceptable entries, it
        % clears them and warns/instructs user
        function inputPanelSubmitCallback(obj, ~, ~)
            if obj.inputsAcceptable
                if obj.useValue
                    % the selected setting for the selected device has either
                    % not had a calibration value stored before, or the user is
                    % electing to overwrite the previous one
                    
                    power = ...
                        str2double(get(obj.ui.calibrationPanel.powerEntry.inputBox, 'String'));
                    spotDiam = ...
                        str2double(get(obj.ui.calibrationPanel.spotSizeEntry.inputBox, 'String'));
                    voltage = ...
                        str2double(get(obj.ui.calibrationPanel.signalEntryRow.inputBox, 'String'));
                    
                    spotSize = pi * spotDiam * spotDiam / 4;
                    
                    calibrationValue = power /(spotSize * voltage);
                    
                    % get device and setting indeces for convenience
                    dev = obj.currentSelection.device;
                    sett = obj.currentSelection.setting;
                    
                    % check if this value is too different 
                    [tooDifferent, percent] = ...
                        obj.tooDifferentFromLastCalibrationValue( ...
                        calibrationValue, ...
                        dev, ...
                        sett);
                    
                    if tooDifferent
                        % make a warning message
                        if percent > 0
                            greaterOrLess = 'greater';
                        else
                            greaterOrLess = 'less';
                        end
                        warningStr = ['The calibration value just entered is: '...
                            num2str(percent) ' percent ' greaterOrLess ' than the most '...
                            'recent calibration value for this device.  Do you '...
                            'still wish to use this value?'];
                        choice = questdlg(warningStr, 'Use value?', 'Yes', 'No', 'No');
                        if strcmp(choice, 'Yes')
                            use = true;
                        else
                            use = false;
                        end
                    else
                        % no warning or issues
                        use = true;
                    end
                    
                    if use
                        % store the new calibration value
                        obj.calibrationValues{dev}(obj.settingsNames{dev}{sett}) = calibrationValue;
                        
                        % mark the setting as calibrated in the listbox THIS
                        % MUST COME BEFORE THE calibratedTFs ARE CHANGED!!!
                        obj.markAsCompleted(dev, sett);
                        
                        % change the TF property to show that the given selection has
                        % been calibrated
                        obj.calibratedTFs{dev}(sett) = true;
                        
                        % move to the next value
                        obj.moveToNext;
                    else
                        % user chose to not use the value because it was
                        % too different from past values
                        % clear the values
                        set(obj.ui.calibrationPanel.powerEntry.inputBox, 'String', '');
                        set(obj.ui.calibrationPanel.spotSizeEntry.inputBox, 'String', '');
                    end
                    
                end
            else
                % clear the values
                set(obj.ui.calibrationPanel.powerEntry.inputBox, 'String', '');
                set(obj.ui.calibrationPanel.spotSizeEntry.inputBox, 'String', '');
                % inputs were not acceptable, make a warning box
                str = ['The inputs just submitted were not acceptable. '...
                    'Both the power and the spot size must be positive numbers.'];
                msgbox(str);
            end
            
        end
        
        % callback for button to use most recent calibration value; checks
        % if a value has been already submitted; if so, asks the user if
        % they want to overwrite with the most recent past calibration; if
        % so, marks as calibrated and moves to next
        function useOldCalibrationCallback(obj, ~, ~)
            if obj.useValue
                
                dev = obj.currentSelection.device;
                sett = obj.currentSelection.setting;
                
                if obj.calibrationValues{dev}.isKey(sett)
                    remove(obj.calibrationValues{dev}, sett);
                end
                
                % mark the setting as calibrated in the listbox THIS
                % MUST COME BEFORE THE calibratedTFs ARE CHANGED!!!
                obj.markAsCompleted(dev, sett);
                
                % change the TF property to show that the given selection has
                % been calibrated
                obj.calibratedTFs{dev}(sett) = true;
                
                % move to the next value
                obj.moveToNext;   
            end
        end
        
        % callback for submit all calibrations button; this button appears
        % once user has calibrated all devices/settings; this method will
        % save any new calibrations and close the UI
        function submitAllCalibrationsButton(obj, ~, ~)
            obj.storeFinalValues();
            obj.addCalibrationsToRig();
            obj.closeUI();
        end
       
        function addCalibrationsToRig(obj)
            for dev = 1:obj.numDevices()
                basePath = [obj.calibrationFolderPath filesep ...
                    obj.devices{dev}.name];
                settings = obj.settingsNames{dev};
                calibrationsMap = containers.Map();
                for sett = 1:numel(settings)
                    logPath = [basePath filesep settings{sett} '.txt'];
                    [calibrationsMap(settings{sett}), ~] = ...
                        edu.washington.riekelab.mardoum.modules.CalibratorUtilities.readMostRecentCalibration(logPath);
                end
                % add the map to the device as a resource...
                obj.devices{dev}.addResource( ...
                    'calibrations', calibrationsMap);
            end
        end
        
        % the method that actually does the saving of the new values
        % (called by submit all calibrations button callback); gets the
        % current time as string, stores this and any new calibrations
        function storeFinalValues(obj)  
            time = datetime();
            for dev = 1:obj.numDevices
                if ~obj.calibrationValues{dev}.isempty();
                    % a new value exists for this device
                    basePath = [obj.calibrationFolderPath filesep ...
                        obj.devices{dev}.name];
                    settings = obj.calibrationValues{dev}.keys();
                    for sett = 1:numel(settings)
                        logPath = [basePath filesep settings{sett} '.txt'];
                        % saves date, value, and adds units
                        edu.washington.riekelab.mardoum.modules.CalibratorUtilities.addCalibrationToLog( ...
                            logPath, ...
                            obj.calibrationValues{dev}(settings{sett}), ...
                            time, ...
                            edu.washington.riekelab.mardoum.modules.CalibratorUtilities.CalibratorConstants.UNITS);
                    end
                end
            end
        end
    end
    
    % Methods that control the devices
    methods
        % takes device object provided, sets background to specified value;
        % if background is nonzero, set 'onButton' to the color for that
        % LED; if it is zero, return it to the default color
        function setDeviceToValue(obj, dev, value)
            dev.background = symphonyui.core.Measurement(value, dev.background.displayUnits);
            dev.applyBackground();

            if value == 0
                set(obj.ui.calibrationPanel.onOffButtons.onButton, 'BackgroundColor', obj.defaultEditBoxColor);
            elseif value > 0
                set(obj.ui.calibrationPanel.onOffButtons.onButton, 'BackgroundColor', obj.determineOnColor);
            end 
        end
        
        % turns off the currently selected device; sets obj.ledOn property
        % to false
        function turnOffSelectedDevice(obj)
            obj.setCurrentDeviceToValue(0);
            obj.ledOn = false;       
        end
        
        % turns on currently selected device to the provided 'signal', and 
        % sets obj.ledOn to true
        function turnOnSelectedDevice(obj, signal)
            obj.setCurrentDeviceToValue(signal);
            obj.ledOn = true;
            
        end
        
        % sets current device to specified value
        function setCurrentDeviceToValue(obj, value)
            dev = obj.devices{obj.currentSelection.device};
            obj.setDeviceToValue(dev, value);         
        end
    end
    
    % For dependent properties
    methods
        function value = get.deviceSelection(obj)
            value = get(obj.ui.deviceList.box, 'Value');
        end
        
        function value = get.settingSelection(obj)
            value = get(obj.ui.deviceSettings.box, 'Value');
        end
        
        function value = get.numDevices(obj)
            value = numel(obj.devices);
        end
        
        % returns value in box where user requests signal for calibration
        function value = get.requestedDeviceSignal(obj)
            value = str2double(get(obj.ui.calibrationPanel.signalEntryRow.inputBox, 'String'));  
        end
        
        % figures out strings for device name and setting to use in
        % title; makes the title string
        function value = get.skipString(obj)
            value = ['Skip calibrating ' obj.deviceName ', ' obj.settingName];
        end
        
        % returns string of last calibration date for selected device
        function value = get.lastCalibrationDate(obj)
            fullDate = ...
                obj.recentCalibrationDates.get(obj.deviceName).get(obj.settingName);
            value = [fullDate(1:2) ' ' fullDate(4:6) ' ' fullDate(8:11)];
        end
        
        % figure out strings for device name and setting to use in
        % title; make the title string   
        function value = get.inputBoxTitleString(obj)
            value = ['Calibrate ' obj.deviceName ', ' obj.settingName];
        end
        
        % returns current device name as string
        function value = get.deviceName(obj)
            deviceName = obj.getDeviceNames;
            value = deviceName{obj.deviceSelection};
        end
        
        % returns current setting name as string
        function value = get.settingName(obj)
            value = ...
                obj.settingsNames{obj.deviceSelection}{obj.settingSelection};
        end
    end
end