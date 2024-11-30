clc; clear; close all;

name = 'Settings';
prompts = {'Subject Name', ...
    'Number of Trials', ...
    'Spatial Frequency', ...
    'Target Initial Contrast', ...
    'Peripheral Contrast', ...
    'Feedback (1: True, 0: Flase)'};

numlines = 1;
defaultanswer = {'XXX', '100', '0.5', '0.2', '0.6', '0'};
answers = inputdlg(prompts, name, numlines, defaultanswer);

fb = str2double(answers{6}); % Feedback. 1 for True, 0 for False
subjectName = answers{1};

% Get current date and time
currentDateTime = datestr(now, 'yyyymmdd_HHMMSS');

% Create a dynamic file name based on subject's name and time
fileName = sprintf('%s_Block5_%s.csv', subjectName, currentDateTime);

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
    
    % Define the size of the fixation cross
    crossLength = 40;  % Length of each arm of the cross (in pixels)
    crossWidth = 5;    % Width of the cross lines (in pixels)
    
    % Get the center of the screen
    [xCenter, yCenter] = RectCenter(windowRect);
    white = WhiteIndex(window);
    gray = white / 2;
    Screen('FillRect', window, gray);
    Screen('Flip', window);
    
    % Initial parameters
    numTrials = str2double(answers{2}); % Max trials
    spatialFrequency = str2double(answers{3}) / (2 * pi); % Cycles per degree for both target and flankers
    targetInitialContrast = str2double(answers{4}); % Starting target contrast
    flankerContrast = str2double(answers{5}); % Flanker contrast (fixed)

    centerToCenterDistance = 5 * (1600*60)/(43.055*57.2958); % Convert 5 degrees to pixels

    % Timing parameters
    fixationDuration = 1; % Fixation cross displayed for 1000 ms
    intervalDuration = 0.25; % Each interval (target/flanker) displayed for 250 ms
    soundDuration = 0.05; % Sound before each interval (50 ms)
    blankDuration = 0.2; % Blank screen duration between intervals (200 ms)
    timeThreshold = 50000; % Time between response and next trial (1000 ms)
    radius = 97;

    % Gabor patch properties
    sigma = 0.8 * (1600*60)/(43.055*57.2958); % Standard deviation of Gaussian envelope in pixel/degree
    [x, y] = meshgrid(-radius:radius, -radius:radius); % Grating grid

    % Generate Gabor patches (target and flankers)
    targetGabor = cos((2 * pi * spatialFrequency) * x) .* exp(-((x).^2 + (y).^2) / (sigma^2));
    flankerGabor = cos((2 * pi * spatialFrequency) * x) .* exp(-((x).^2 + (y).^2) / (sigma^2));

    % Response keys
    firstIntervalKey = KbName('1!'); % First interval key
    secondIntervalKey = KbName('2@'); % Second interval key
    
    % Variables to store data
    results = cell(numTrials, 6);

    % Start task
    for trial = 1:numTrials     
        % Draw fixation cross
        Screen('DrawLine', window, white, xCenter - crossLength, yCenter, xCenter + crossLength, yCenter, crossWidth);
        Screen('DrawLine', window, white, xCenter, yCenter - crossLength, xCenter, yCenter + crossLength, crossWidth);
        Screen('Flip', window);
        WaitSecs(fixationDuration); % Show fixation cross for 1000 ms
        
        % Create textures for target and flanker Gabor patches
        targetTexture = Screen('MakeTexture', window, gray + targetInitialContrast * (white - gray) * targetGabor);
        flankerTexture = Screen('MakeTexture', window, gray + flankerContrast * (white - gray) * flankerGabor);

        % Randomly choose which interval (1 or 2) will contain the target
        targetInterval = randi([1, 2]);
        
        % Play intervals
        for interval = 1:2
            % Play sound before each interval
            Beeper(800, 1, soundDuration);
            WaitSecs(soundDuration);
            
            % Draw stimuli
            if interval == targetInterval
                % Target and flankers in the same interval
                Screen('DrawTexture', window, targetTexture, [], [xCenter-radius, yCenter-radius, xCenter+radius, yCenter+radius]);
            end

            % Draw flankers above and below
            Screen('DrawTexture', window, flankerTexture, [], [xCenter-radius, yCenter-centerToCenterDistance-radius, xCenter+radius, yCenter-centerToCenterDistance+radius]);
            Screen('DrawTexture', window, flankerTexture, [], [xCenter-radius, yCenter+centerToCenterDistance-radius, xCenter+radius, yCenter+centerToCenterDistance+radius]);

            Screen('Flip', window);
            WaitSecs(intervalDuration);
            
            if interval == 2
                break;
            end

            Screen('FillRect', window, gray); % Blank screen between intervals
            Screen('Flip', window);
            WaitSecs(blankDuration);
        end

        % Draw fixation cross
        Screen('DrawLine', window, white, xCenter - crossLength, yCenter, xCenter + crossLength, yCenter, crossWidth);
        Screen('DrawLine', window, white, xCenter, yCenter - crossLength, xCenter, yCenter + crossLength, crossWidth);
        Screen('Flip', window);

        % Get participant response
        startTime = GetSecs;
        correct = false;
        pressedKey = 'None';
        while GetSecs - startTime < timeThreshold
            [keyIsDown, secs, keyCode] = KbCheck;
            if keyIsDown
                if keyCode(firstIntervalKey)
                    pressedKey = '1';
                    correct = (targetInterval == 1);
                elseif keyCode(secondIntervalKey)
                    pressedKey = '2';
                    correct = (targetInterval == 2);
                end
                break;
            end
        end
        
        % If no key was pressed within the threshold, set reaction time to timeThreshold
        if ~keyIsDown
            secs = startTime + timeThreshold;
        end
        
        reactionTime = secs - startTime;

        % Save results
        results{trial, 1} = trial;
        results{trial, 2} = targetInterval;
        results{trial, 3} = pressedKey; % Pressed Key (1/2)
        results{trial, 4} = correct;
        results{trial, 5} = reactionTime; % Reaction time
        results{trial, 6} = targetInitialContrast;

        % Update the contrast based on correctness (1-up, 3-down staircase)
        if correct
            targetInitialContrast = max(0, targetInitialContrast * 10^(-0.1)); % Decrease by 0.1 log units
        else
            targetInitialContrast = min(1, targetInitialContrast * 10^(0.3));  % Increase by 0.3 log units
        end
        
        if targetInitialContrast > 1
            targetInitialContrast = 1;
        elseif targetInitialContrast < 0
            targetInitialContrast = 0;
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
  
        % Show blank screen for 1 second before next trial
        Screen('FillRect', window, gray);
        Screen('Flip', window);
        WaitSecs(1);
    end

    % Save results to CSV
    headers = {'Trial', 'TargetInterval', 'PressedInterval', 'Correct', 'ReactionTime', 'Contrast'};
    fid = fopen(fileName, 'w');
    fprintf(fid, '%s, %s, %s, %s, %s, %s\n', headers{:});
    fclose(fid);
    
    for trial = 1:numTrials
        fid = fopen(fileName, 'a');
        fprintf(fid, '%d, %d, %s, %d, %.4f, %.4f\n', results{trial, 1}, results{trial, 2}, results{trial, 3}, results{trial, 4}, results{trial, 5}, results{trial, 6});
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
requiredColumns = 9;
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
if width(data) >= 9
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
if length(reversal_indices) < 10
    disp('Not enough reversals found in the data.');
    % Optionally, you can choose to leave the cell empty or assign a specific value
    % Here, we leave it empty as per your requirement
else
    % Step 5: Get the last 8 reversal indices
    last_8_reversal_indices = reversal_indices(end-9:end);  % Get last 8 reversal indices
    
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