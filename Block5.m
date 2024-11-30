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

currentDateTime = datestr(now, 'yyyymmdd_HHMMSS');

fileName = sprintf('%s_Block5_%s.csv', subjectName, currentDateTime);

Screen('Preference', 'SkipSyncTests', 1);
KbName('UnifyKeyNames');
AssertOpenGL;

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
    
    numTrials = str2double(answers{2}); % Max trials
    spatialFrequency = str2double(answers{3}) / (2 * pi); % Cycles per degree for both target and flankers
    targetInitialContrast = str2double(answers{4}); % Starting target contrast
    flankerContrast = str2double(answers{5}); % Flanker contrast (fixed)

    centerToCenterDistance = 5 * (1600*60)/(43.055*57.2958); % Convert 5 degrees to pixels

    fixationDuration = 1; % Fixation cross displayed for 1000 ms
    intervalDuration = 0.25; % Each interval (target/flanker) displayed for 250 ms
    soundDuration = 0.05; % Sound before each interval (50 ms)
    blankDuration = 0.2; % Blank screen duration between intervals (200 ms)
    timeThreshold = 50000; % Time between response and next trial (1000 ms)
    radius = 97;

    sigma = 0.8 * (1600*60)/(43.055*57.2958); % Standard deviation of Gaussian envelope in pixel/degree
    [x, y] = meshgrid(-radius:radius, -radius:radius); % Grating grid

    targetGabor = cos((2 * pi * spatialFrequency) * x) .* exp(-((x).^2 + (y).^2) / (sigma^2));
    flankerGabor = cos((2 * pi * spatialFrequency) * x) .* exp(-((x).^2 + (y).^2) / (sigma^2));

    firstIntervalKey = KbName('1!'); % First interval key
    secondIntervalKey = KbName('2@'); % Second interval key
    
    results = cell(numTrials, 6);

    for trial = 1:numTrials     
        Screen('DrawLine', window, white, xCenter - crossLength, yCenter, xCenter + crossLength, yCenter, crossWidth);
        Screen('DrawLine', window, white, xCenter, yCenter - crossLength, xCenter, yCenter + crossLength, crossWidth);
        Screen('Flip', window);
        WaitSecs(fixationDuration);
        
        targetTexture = Screen('MakeTexture', window, gray + targetInitialContrast * (white - gray) * targetGabor);
        flankerTexture = Screen('MakeTexture', window, gray + flankerContrast * (white - gray) * flankerGabor);

        targetInterval = randi([1, 2]);
        
        for interval = 1:2
            Beeper(800, 1, soundDuration);
            WaitSecs(soundDuration);
            
            if interval == targetInterval
                Screen('DrawTexture', window, targetTexture, [], [xCenter-radius, yCenter-radius, xCenter+radius, yCenter+radius]);
            end

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

        Screen('DrawLine', window, white, xCenter - crossLength, yCenter, xCenter + crossLength, yCenter, crossWidth);
        Screen('DrawLine', window, white, xCenter, yCenter - crossLength, xCenter, yCenter + crossLength, crossWidth);
        Screen('Flip', window);

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
        
        if ~keyIsDown
            secs = startTime + timeThreshold;
        end
        
        reactionTime = secs - startTime;

        results{trial, 1} = trial;
        results{trial, 2} = targetInterval;
        results{trial, 3} = pressedKey; % Pressed Key (1/2)
        results{trial, 4} = correct;
        results{trial, 5} = reactionTime; % Reaction time
        results{trial, 6} = targetInitialContrast;

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

        
        if fb == 1
            if correct == 1
                feedbackMessage = 'Correct!';
                feedbackColor = [0 255 0]; % Green
            else
                feedbackMessage = 'Incorrect!';
                feedbackColor = [255 0 0]; % Red
            end
            Screen('TextSize', window, 40);
            Screen('TextFont', window, 'Arial');

            DrawFormattedText(window, feedbackMessage, 'center', 'center', feedbackColor);
            Screen('Flip', window);
            WaitSecs(1);
        end
  
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

    Screen('CloseAll');
    fprintf('Experiment completed. Results saved to "%s".\n', fileName);
    
catch ME
    Screen('CloseAll');
    rethrow(ME);
end

%% Calculate last 8 reversals
data = readtable(fileName);

numColumns = width(data);
disp(['Number of columns in the table: ', num2str(numColumns)]);

requiredColumns = 9;
if numColumns < requiredColumns
    colsToAdd = requiredColumns - numColumns;
    
    for i = 1:colsToAdd
        newVarName = sprintf('NewVar%d', numColumns + i);
        data.(newVarName) = repmat({''}, height(data), 1);
    end
end

if width(data) >= 9
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

if length(reversal_indices) < 10
    disp('Not enough reversals found in the data.');
else
    last_8_reversal_indices = reversal_indices(end-9:end);  % Get last 8 reversal indices
    
    contrast_values = data.Contrast(last_8_reversal_indices);
    
    average_contrast = mean(contrast_values, 'omitnan');  % 'omitnan' ignores NaN values
    
    targetRow = 1;  % Change this as needed
    if targetRow > height(data)
        error('The target row exceeds the number of rows in the table.');
    end
    data.AvgContrastLast8Reversals{targetRow, 1} = num2str(average_contrast);
    
    disp(['Average Contrast of the last 8 reversals: ', num2str(average_contrast)]);
end

writetable(data, fileName);