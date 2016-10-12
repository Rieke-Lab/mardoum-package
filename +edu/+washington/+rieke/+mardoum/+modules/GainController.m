classdef GainController < symphonyui.ui.Module
   
    properties
       leds 
       figureHandle
       ledListeners
       mainLayout
       gainSettingsRows
    end       
    
    
    properties (Constant)
        RED_SELECTED = [1 0.2 0.2]
        GREEN_SELECTED = [0.2 1 0.2]
        BLUE_SELECTED = [0.2 0.2 1]
        UV_SELECTED = [0.8 0.5 1]
    end
    
    methods
        function createUi(obj, figureHandle)
            import appbox.*;
            obj.figureHandle = figureHandle;
            set(obj.figureHandle, ...
                'Name', 'Gain Controller', ...
                'Position', screenCenter(250, 80));
            
            obj.mainLayout = uix.VBox( ...
                'Parent', obj.figureHandle);
        end
        
        function populateUI(obj)
            % add LEDs and their current gains
            
            obj.gainSettingsRows = cell(1, numel(obj.leds));
            for i = 1:numel(obj.leds)
                obj.gainSettingsRows{i} = edu.washington.riekelab.weber.modules.gainControllerUtilities.GainSettingsRow( ...
                    obj.leds{i}, ...
                    obj.mainLayout);
            end
        end
    end
    
    methods (Access = protected)
        function willGo(obj)
            obj.leds = obj.configurationService.getDevices('LED');
            obj.populateUI();
        end
        
        function bind(obj)
            bind@symphonyui.ui.Module(obj);

            c = obj.configurationService;
            obj.addListener(c, 'InitializedRig', @obj.onServiceInitializedRig);
        end
    end
    
    methods (Access = private)
        function onServiceInitializedRig(obj, ~, ~)
            % flush out and reset everything
            clf(obj.figureHandle);
            obj.createUi(obj.figureHandle);
            obj.leds = obj.configurationService.getDevices('LED');
            obj.populateUI();
        end
    end
end