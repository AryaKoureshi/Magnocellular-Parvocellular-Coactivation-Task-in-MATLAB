close all; clear; clc;

name = 'Settings';
prompts = {'Subject Name', ...
    'Number of Trials', ...
    'Spatial Frequency', ...
    'Temporal Frequency', ...
    'Initial Contrast', ...
    'Feedback (1: True, 0: Flase)'};

numlines = 1;
defaultanswer = {'XXX', '100', '0.5', '16', '0.85', '0'};
answers = inputdlg(prompts, name, numlines, defaultanswer);

fb = str2double(answers{6}); % Feedback. 1 for True, 0 for False
subjectName = answers{1};

currentDateTime = datestr(now, 'yyyymmdd_HHMMSS');

fileName = sprintf('%s_Block1_%s.csv', subjectName, currentDateTime);

Screen('Preference', 'SkipSyncTests', 1);
KbName('UnifyKeyNames');
AssertOpenGL;

InitializePsychSound(1);

freq = 44100; % Sampling rate
nrchannels = 2; % Stereo sound

pahandle = PsychPortAudio('Open', [], 1, 1, freq, nrchannels);

beepFreq = 1000; % Beep frequency in Hz
beepDuration = 0.2; % Beep duration in seconds

t = 0:1/freq:beepDuration;

beepSound = 0.5 * sin(2 * pi * beepFreq * t);

beepSound = [beepSound; beepSound];

try
    [window, windowRect] = Screen('OpenWindow', max(Screen('Screens')));
    [screenXpixels, screenYpixels] = Screen('WindowSize', window);
    
    crossLength = 40;  % Length of each arm of the cross (in pixels)
    crossWidth = 5;    % Width of the cross lines (in pixels)
    
    [xCenter, yCenter] = RectCenter(windowRect);
    white = WhiteIndex(window);
    gray = white / 2;
    Screen('FillRect', window, gray);
    Screen('Flip', window);
    
    numTrials = str2double(answers{2});
    spatialFrequency = str2double(answers{3}) / (2 * pi); % 0.5 Cycles per degree
    temporalFrequency = str2double(answers{4}); % Degrees per second
    sigma = 1 * (1600*60)/(43.055*57.2958); % Standard deviation of Gaussian envelope in pixel/degree
    initialContrast = str2double(answers{5}); % Initial contrast value
    timeThreshold = 50000; % Maximum allowed time for response (seconds)
    duration = 0.075;
    radius = 97; % Pixels

    phase = 0;
    refreshRate = Screen('NominalFrameRate', window); % Get screen refresh rate
    phaseIncrement = (temporalFrequency * 2 * pi) / refreshRate; % Phase shift per frame
    durationFrames = round(duration * refreshRate);

    leftKey = KbName('LeftArrow');
    rightKey = KbName('RightArrow');
    
    results = cell(numTrials, 6);
    
    for trial = 1:numTrials
        Screen('DrawLine', window, white, xCenter - crossLength, yCenter, xCenter + crossLength, yCenter, crossWidth); % Horizontal line
        Screen('DrawLine', window, white, xCenter, yCenter - crossLength, xCenter, yCenter + crossLength, crossWidth); % Vertical line
        Screen('Flip', window);
        WaitSecs(1);
        
        direction = randi([0, 1]); % 0 for left, 1 for right
        if direction == 0
            realDirection = 'Left';
        else
            realDirection = 'Right';
        end

        [x, y] = meshgrid(-radius:radius, -radius:radius);
        Gabor = cos((2 * pi * spatialFrequency) * x + phase) .* exp(-((x).^2 + (y).^2) / (sigma^2));
        GaborTexture = Screen('MakeTexture', window, gray + initialContrast * (white - gray) * Gabor);
        
        for frame = 1:durationFrames
            phase = phase + phaseIncrement;
            Gabor = cos((2 * pi * spatialFrequency) * x + phase) .* exp(-((x).^2 + (y).^2) / (sigma^2));
            GaborTexture = Screen('MakeTexture', window, gray + initialContrast * (white - gray) * Gabor);
            Screen('DrawTexture', window, GaborTexture, [], [], direction * 180);
            Screen('Flip', window);
        end
        
        Screen('DrawLine', window, white, xCenter - crossLength, yCenter, xCenter + crossLength, yCenter, crossWidth); % Horizontal line
        Screen('DrawLine', window, white, xCenter, yCenter - crossLength, xCenter, yCenter + crossLength, crossWidth); % Vertical line
        Screen('Flip', window);
        
        startTime = GetSecs;
        correct = false;
        pressedDirection = 'None';
        while GetSecs - startTime < timeThreshold
            [keyIsDown, secs, keyCode] = KbCheck;
            if keyIsDown
                if keyCode(leftKey)
                    pressedDirection = 'Left';
                elseif keyCode(rightKey)
                    pressedDirection = 'Right';
                end
                
                if ~strcmp(pressedDirection, 'None')
                    correct = strcmp(pressedDirection, realDirection); % Compare with real direction
                    break;
                end
            end
        end
        
        if ~keyIsDown
            secs = startTime + timeThreshold;
        end
        
        reactionTime = secs - startTime;
        
        
        results{trial, 1} = trial; % Trial number
        results{trial, 2} = realDirection; % Real direction (Left/Right)
        results{trial, 3} = pressedDirection; % Pressed direction (Left/Right)
        results{trial, 4} = correct; % Correct (1 or 0)
        results{trial, 5} = reactionTime; % Reaction time
        results{trial, 6} = initialContrast; % Contrast
        
        if correct
            initialContrast = max(0, initialContrast * 10^(-0.1)); % Decrease by 0.1 log units
        else
            initialContrast = min(1, initialContrast * 10^(0.3));  % Increase by 0.3 log units
        end
        
        if initialContrast > 1
            initialContrast = 1;
        elseif initialContrast < 0
            initialContrast = 0;
        end
        
        if fb == 1
            if correct == 1
        
                PsychPortAudio('FillBuffer', pahandle, beepSound);
        
                PsychPortAudio('Start', pahandle, 1, 0, 1);
        
                WaitSecs(beepDuration);
        
                PsychPortAudio('Stop', pahandle);
            else
                WaitSecs(0.2);
            end
        end

        Screen('FillRect', window, gray);
        Screen('Flip', window);
        WaitSecs(1);
    end
    
    headers = {'Trial', 'RealDirection', 'PressedDirection', 'Correct', 'ReactionTime', 'Contrast'};
    
    fid = fopen(fileName, 'w');
    fprintf(fid, '%s, %s, %s, %s, %s, %s\n', headers{:});
    fclose(fid);
    
    for trial = 1:numTrials
        fid = fopen(fileName, 'a');
        fprintf(fid, '%d, %s, %s, %d, %.4f, %.4f\n', results{trial, 1}, results{trial, 2}, results{trial, 3}, results{trial, 4}, results{trial, 5}, results{trial, 6});
        fclose(fid);
    end
    
    Screen('CloseAll');
    fprintf('Experiment completed. Results saved to "%s".\n', fileName);
    
catch ME
    Screen('CloseAll');
    rethrow(ME);
end
PsychPortAudio('Close', pahandle);


%% Calculate last 8 reversals 
data = readtable(fileName);

numColumns = width(data);
disp(['Number of columns in the table: ', num2str(numColumns)]);

requiredColumns = 7;
if numColumns < requiredColumns
    colsToAdd = requiredColumns - numColumns;
    
    for i = 1:colsToAdd
        newVarName = sprintf('NewVar%d', numColumns + i);
        data.(newVarName) = repmat({''}, height(data), 1);
    end
end

if width(data) >= 7
    data.Properties.VariableNames{7} = 'AvgContrastLast8Reversals';
else
    error('The table does not have enough columns even after adding.');
end

data.AvgContrastLast8Reversals = repmat({''}, height(data), 1);

if ~ismember('Correct', data.Properties.VariableNames)
    error('The table does not contain a ''Correct'' column.');
end

if ~ismember('Contrast', data.Properties.VariableNames)
    error('The table does not contain a ''Contrast'' column.');
end

reversals = [false; diff(data.Correct) ~= 0];

reversal_indices = find(reversals);

if length(reversal_indices) < 8
    disp('Not enough reversals found in the data.');
else
    last_8_reversal_indices = reversal_indices(end-7:end);
    
    contrast_values = data.Contrast(last_8_reversal_indices);
    
    average_contrast = mean(contrast_values, 'omitnan');
    
    targetRow = 1;
    if targetRow > height(data)
        error('The target row exceeds the number of rows in the table.');
    end
    data.AvgContrastLast8Reversals{targetRow, 1} = num2str(average_contrast);
    
    disp(['Average Contrast of the last 8 reversals: ', num2str(average_contrast)]);
end

writetable(data, fileName);
