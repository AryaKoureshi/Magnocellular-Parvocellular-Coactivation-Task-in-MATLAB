clc; clear; close all;

name = 'Settings';
prompts = {'Subject Name', ...
    'Number of Trials', ...
    'Spatial Frequency', ...
    'Peripheral Spatial Frequency', ...
    'Temporal Frequency', ...
    'Initial Contrast', ...
    'Peripheral Contrast', ...
    'Feedback (1: True, 0: Flase)'};

numlines = 1;
defaultanswer = {'XXX', '100', '0.5', '0.125', '16', '0.85', '0.6', '0'};
answers = inputdlg(prompts, name, numlines, defaultanswer);

fb = str2double(answers{8}); % Feedback. 1 for True, 0 for False
subjectName = answers{1};

% Get current date and time
currentDateTime = datestr(now, 'yyyymmdd_HHMMSS');

% Create a dynamic file name based on subject's name and time
fileName = sprintf('%s_Block3_%s.csv', subjectName, currentDateTime);

% Setup Psychtoolbox
Screen('Preference', 'SkipSyncTests', 1);
KbName('UnifyKeyNames');
AssertOpenGL;

% Initialize PsychSound
InitializePsychSound(1);

% Set the frequency and number of channels
freq = 44100; % Sampling rate
nrchannels = 2; % Stereo sound

% Open the default audio device
pahandle = PsychPortAudio('Open', [], 1, 1, freq, nrchannels);

% Parameters for the beep sound
beepFreq = 1000; % Beep frequency in Hz
beepDuration = 0.2; % Beep duration in seconds

% Generate time vector
t = 0:1/freq:beepDuration;

% Generate the beep sound waveform
beepSound = 0.5 * sin(2 * pi * beepFreq * t);

% Duplicate for stereo sound
beepSound = [beepSound; beepSound];

try
    % Screen setup
    [window, windowRect] = Screen('OpenWindow', max(Screen('Screens')));
    [screenXpixels, screenYpixels] = Screen('WindowSize', window);
    
    % Define the size of the cross
    crossLength = 40;  % Length of each arm of the cross (in pixels)
    crossWidth = 5;    % Width of the cross lines (in pixels)
    
    % Get the center of the screen
    [xCenter, yCenter] = RectCenter(windowRect);
    white = WhiteIndex(window);
    gray = white / 2;
    Screen('FillRect', window, gray);
    Screen('Flip', window);
    
    % Initial parameters
    numTrials = str2double(answers{2});
    spatialFrequency = str2double(answers{3}) / (2 * pi); % Cycles per degree
    spatialFrequency_peripheral = str2double(answers{4}) / (2 * pi); % 0.125 Cycles per degree
    temporalFrequency = str2double(answers{5}); % Degrees per second
    sigma = 1 * (1600*60)/(43.055*57.2958); % Standard deviation of Gaussian envelope in pixel/degree
    initialContrast = str2double(answers{6}); % Initial contrast value for target grating
    peripheralContrast = str2double(answers{7}); % Contrast for peripheral gratings
    timeThreshold = 500000; % Maximum allowed time for response (seconds)
    duration = 0.075;
    radius = 97; % Pixels

    % Stimulus properties
    phase = 0;
    refreshRate = Screen('NominalFrameRate', window); % Get screen refresh rate
    phaseIncrement = (temporalFrequency * 2 * pi) / refreshRate; % Phase shift per frame
    durationFrames = round(duration * refreshRate);    

    % Peripheral grating positions (center-to-center distance: 3 degrees)
    peripheralDistance = 5 * (1600*60)/(43.055*57.2958); % Convert 3 degrees to pixels
    
    % Response settings
    leftKey = KbName('LeftArrow');
    rightKey = KbName('RightArrow');
    
    % Variables to store data
    results = cell(numTrials, 6); % Cell array to allow for string entries for directions
    
    % Start task
    for trial = 1:numTrials
        % Draw fixation cross
        Screen('DrawLine', window, white, xCenter - crossLength, yCenter, xCenter + crossLength, yCenter, crossWidth);
        Screen('DrawLine', window, white, xCenter, yCenter - crossLength, xCenter, yCenter + crossLength, crossWidth);
        Screen('Flip', window);
        WaitSecs(1); % Show fixation cross for 1000 ms
        
        % Determine direction randomly (left or right)
        direction = randi([0, 1]); % 0 for left, 1 for right
        if direction == 0
            realDirection = 'Left';
        else
            realDirection = 'Right';
        end

        % Generate Gabor patches
        [x, y] = meshgrid(-radius:radius, -radius:radius);
        targetGabor = cos((2 * pi * spatialFrequency) * x + phase) .* exp(-((x).^2 + (y).^2) / (sigma^2));
        peripheralGabor = cos((2 * pi * spatialFrequency_peripheral) * x) .* exp(-((x).^2 + (y).^2) / (sigma^2));
        
        targetTexture = Screen('MakeTexture', window, gray + initialContrast * (white - gray) * targetGabor);
        peripheralTexture = Screen('MakeTexture', window, gray + peripheralContrast * (white - gray) * peripheralGabor);
        
        start00 = GetSecs;
        % Display animated gratings for 75 ms
        for frame = 1:durationFrames
            phase = phase + phaseIncrement;
            targetGabor = cos((2 * pi * spatialFrequency) * x + phase) .* exp(-((x).^2 + (y).^2) / (sigma^2));
            targetTexture = Screen('MakeTexture', window, gray + initialContrast * (white - gray) * targetGabor);
            
            % Draw peripheral gratings (above and below)
            Screen('DrawTexture', window, peripheralTexture, [], [xCenter-radius, yCenter-peripheralDistance-radius, xCenter+radius, yCenter-peripheralDistance+radius]);
            Screen('DrawTexture', window, peripheralTexture, [], [xCenter-radius, yCenter+peripheralDistance-radius, xCenter+radius, yCenter+peripheralDistance+radius]);
            
            % Draw target grating (center, moving)
            Screen('DrawTexture', window, targetTexture, [], [xCenter-radius, yCenter-radius, xCenter+radius, yCenter+radius], direction * 180);
            Screen('Flip', window);
        end
        stop00 = GetSecs;

        % Draw fixation cross again
        Screen('DrawLine', window, white, xCenter - crossLength, yCenter, xCenter + crossLength, yCenter, crossWidth);
        Screen('DrawLine', window, white, xCenter, yCenter - crossLength, xCenter, yCenter + crossLength, crossWidth);
        Screen('Flip', window);
        
        % Measure reaction time and get response
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
                    correct = strcmp(pressedDirection, realDirection);
                    break;
                end
            end
        end
        
        % If no key was pressed within the threshold, set reaction time to timeThreshold
        if ~keyIsDown
            secs = startTime + timeThreshold;
        end
        
        reactionTime = secs - startTime;
        
        % Store results for this trial
        results{trial, 1} = trial; % Trial number
        results{trial, 2} = realDirection; % Real direction (Left/Right)
        results{trial, 3} = pressedDirection; % Pressed direction (Left/Right)
        results{trial, 4} = correct; % Correct (1 or 0)
        results{trial, 5} = reactionTime; % Reaction time
        results{trial, 6} = initialContrast; % Contrast

        % Update the contrast based on correctness (1-up, 3-down staircase)
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

        % Determine feedback message
        if fb == 1
            if correct == 1
                % Play beep sound for correct answer
        
                % Fill the audio buffer with the beep sound
                PsychPortAudio('FillBuffer', pahandle, beepSound);
        
                % Start audio playback
                PsychPortAudio('Start', pahandle, 1, 0, 1);
        
                % Wait for the beep to finish playing
                WaitSecs(beepDuration);
        
                % Stop playback (optional)
                PsychPortAudio('Stop', pahandle);
            else
                % Do nothing for incorrect answer
                % Optionally, add a short pause
                WaitSecs(0.2);
            end
        end

        % Show a blank screen for 1 second between trials
        Screen('FillRect', window, gray);
        Screen('Flip', window);
        WaitSecs(1);
    end
    
    % Column headers for the CSV file
    headers = {'Trial', 'RealDirection', 'PressedDirection', 'Correct', 'ReactionTime', 'Contrast'};
    
    % Write headers and data to the CSV file
    fid = fopen(fileName, 'w');
    fprintf(fid, '%s, %s, %s, %s, %s, %s\n', headers{:});
    fclose(fid);
    
    % Append the trial data to the file
    for trial = 1:numTrials
        fid = fopen(fileName, 'a');
        fprintf(fid, '%d, %s, %s, %d, %.4f, %.4f\n', results{trial, 1}, results{trial, 2}, results{trial, 3}, results{trial, 4}, results{trial, 5}, results{trial, 6});
        fclose(fid);
    end
    
    % Close the screen
    Screen('CloseAll');
    fprintf('Experiment completed. Results saved to "%s".\n', fileName);
    
catch ME
    Screen('CloseAll');
    rethrow(ME);
end

% At the end of your script
PsychPortAudio('Close', pahandle);

%% Calculate last 8 reversals
data = readtable(fileName);

% Step 2: Check the number of columns
numColumns = width(data);
disp(['Number of columns in the table: ', num2str(numColumns)]);

% Step 3: Add new columns if necessary to ensure at least 7 columns
requiredColumns = 7;
if numColumns < requiredColumns
    % Number of columns to add
    colsToAdd = requiredColumns - numColumns;
    
    for i = 1:colsToAdd
        % Generate a unique variable name for new columns
        newVarName = sprintf('NewVar%d', numColumns + i);
        % Initialize new column with empty strings
        data.(newVarName) = repmat({''}, height(data), 1);
    end
end

% Step 4: Set the name of the 7th column
% Ensure that VariableNames has at least 7 entries
if width(data) >= 7
    data.Properties.VariableNames{7} = 'AvgContrastLast8Reversals';
else
    error('The table does not have enough columns even after adding.');
end

% Step 5: Initialize the 7th column with empty strings
% Convert the 7th column to a cell array of strings with empty entries
data.AvgContrastLast8Reversals = repmat({''}, height(data), 1);

% Step 6: Your Provided Analysis Code
% -----------------------------------

% Step 1: Check for 'Correct' and 'Contrast' columns
if ~ismember('Correct', data.Properties.VariableNames)
    error('The table does not contain a ''Correct'' column.');
end

if ~ismember('Contrast', data.Properties.VariableNames)
    error('The table does not contain a ''Contrast'' column.');
end

% Step 2: Find reversals in the 'Correct' column
% A reversal occurs when the value in 'Correct' changes between consecutive rows
reversals = [false; diff(data.Correct) ~= 0];

% Step 3: Find the indices of all reversals
reversal_indices = find(reversals);  % Indices of all reversals

% Step 4: Ensure there are at least 8 reversals to avoid indexing errors
if length(reversal_indices) < 8
    disp('Not enough reversals found in the data.');
    % Optionally, you can choose to leave the cell empty or assign a specific value
    % Here, we leave it empty as per your requirement
else
    % Step 5: Get the last 8 reversal indices
    last_8_reversal_indices = reversal_indices(end-7:end);  % Get last 8 reversal indices
    
    % Step 6: Extract the 'Contrast' values corresponding to these reversals
    contrast_values = data.Contrast(last_8_reversal_indices);
    
    % Step 7: Calculate the average of these 'Contrast' values
    average_contrast = mean(contrast_values, 'omitnan');  % 'omitnan' ignores NaN values
    
    % Step 8: Assign the average_contrast to the desired cell in the 7th column
    % For example, assigning to the 2nd row
    targetRow = 1;  % Change this as needed
    if targetRow > height(data)
        error('The target row exceeds the number of rows in the table.');
    end
    data.AvgContrastLast8Reversals{targetRow, 1} = num2str(average_contrast);
    
    % Display the result
    disp(['Average Contrast of the last 8 reversals: ', num2str(average_contrast)]);
end

% Step 7: Save the modified table back to the CSV file
writetable(data, fileName);
