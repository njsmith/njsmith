function PilotExperiment(subjnum, computer)

tic

% Use a repeatable random stream for each subject
r = RandStream('mt19937ar', 'seed', subjnum);
outpath = sprintf('resp-%03i.txt', subjnum);

% Set Up Stuff
params.stdDelayTime  = 0.200;
params.nSig = 3.5;
params.minDelayTime  = 0.050;

params.meanDelayTime = params.minDelayTime + params.nSig * params.stdDelayTime;
params.maxDelayTime  = 2*params.minDelayTime + 2*params.nSig * params.stdDelayTime;

params.scoreScreenDuration = 1.000;
params.readyScreenDuration = 1.000;
% If their RT is <50ms then they jumped the gun.
params.minResponseTime = 0.050;

trialsPerPractise = 3;
trialsPerBlock = 3;
numberOfBlocks = 2;
wrapChars = 50;

% points
params.penaltyPoints = -1000;
params.penaltyTime = 5;
% normal trials
params.minRespTime  = 0.075;
params.maxScoreTime = 0.425;
% speedy trials
params.cutoffQuantile = 0.33;
params.chanceOfSpeedyTrial = 0.25;
params.cutoffTime = NaN; % to be set after practise trials
params.bonusPoints = 500;
% set background grey level for stimuli Screen
bkgrndGreyLevel = 100;

% To get input device: GetMouseIndices, GetKeyboardIndices,
% GetGamepadIndices.
% To identify a gamepad: Gamepad('GetGamepadNamesFromIndices', indices)
input_buttons = zeros(256, 1);
if strcmp(computer, 'test')
    % Default -- keyboard
    % For some reason nothing else works :-( :-(
    % But hopefully on OS-X things will be better?
    input_device = [];
    % space bar
    input_buttons(kbname('space')) = 1;
elseif strcmp(computer, 'lab-gamepad')
    input_device = Gamepad('GetGamepadIndicesFromNames', 'Logitech Dual Action');
    input_buttons([5, 6]) = 1;
    Screen('Preference', 'DefaultFontSize', 36);
    Priority(9);
else
    error('unknown computer');
end

% Tell Psychtoolbox to start monitoring for button presses on the given
% device. This starts a thread in the background that does nothing but poll
% the given device, and records accurate time stamps. So that means we
% don't have to worry about polling in our code here; we can just check the
% queue occasionally and it will tell us when any buttons were pressed.
KbQueueCreate(input_device, input_buttons);

try
    % create stimuliScrn
    %Screen('Preference', 'SkipSyncTests', 0);

    HideCursor();
    stimuliScrn = Screen('OpenWindow', 0, bkgrndGreyLevel);
    [w, h] = Screen('WindowSize', stimuliScrn);
    ifi = Screen('GetFlipInterval', stimuliScrn);
    Screen('Flip', stimuliScrn);
    
    % load the various textures
    t_ready_regular = Screen('MakeTexture', stimuliScrn, imread('get-ready-regular.png'));    
    t_ready_bonus = Screen('MakeTexture', stimuliScrn, imread('get-ready-bonus-round.png'));
    t_go = Screen('MakeTexture', stimuliScrn, imread('go.png'));
    t_too_early = Screen('MakeTexture', stimuliScrn, imread('too-early.png'));
    t_blank = Screen('MakeTexture', stimuliScrn, bkgrndGreyLevel*ones(1024));
    
    disp('*starting experiment*');
    KbQueueStart(input_device);
    results = [];
    
    textScreen('Lets start with some practice! (XX)', 'wait');
    results = [results RunBlock(r, 1, 1, 2, trialsPerPractise, 0)];
    
    % calculate median response time
    disp('trying to get deadline response time');
    params.cutoffTime = my_quantile(without_nan([results.resp_latency]), params.cutoffQuantile);
    params.cutoffTime
    % XX show instructions about bonus trials
    textScreen('Now we''ll add bonus trials! (XX)', 'wait');
    results = [results RunBlock(r, 1, 2, 2, trialsPerPractise, 1)];
    textScreen('Any questions? Press any button when you''re ready to start the real experiment.', 'wait');
    %% start experiment for real!
    for block = 1:numberOfBlocks
        results = [results RunBlock(r, 0, block, numberOfBlocks, trialsPerBlock, 1)];
        save(outpath, '-v6', 'subjnum', 'results', 'params');
    end % end of a block
    %% thank you screen
    WaitSecs(0.1);
    Screen('DrawTexture',stimuliScrn,t_blank);
    non_practice_trials = [results.isPractice] == 0;
    all_points = [results.points];
    total_score = sum(all_points(non_practice_trials));
    DrawFormattedText(stimuliScrn, ['Thank you for taking part!\n ' int2str(total_score) ' points in total!!!'], 'center', 'center');
    Screen('Flip',stimuliScrn,0);
    KbQueueWait(input_device);
    fprintf('Total score: %i\n', total_score);
    save(outpath, '-v6', 'subjnum', 'total_score', 'results', 'params');
    
    KbQueueRelease(input_device);
    Screen('CloseAll');
    ShowCursor();
    
catch me
    ShowCursor();
    KbQueueRelease(input_device);
    Screen('CloseAll');
    disp('error')
    disp(me)
    
end

Priority(0);
toc;

    function blockResults = RunBlock(r, isPractice, blockNum, totalBlocks, trialCount, includeBonus)
        blockResults = [];
        blockPoints = 0;
        for trial = 1:trialCount
            if includeBonus && (rand(r) < params.chanceOfSpeedyTrial)
                trialType = 'bonus';
            else
                trialType = 'regular';
            end
            trial_results = RunTrial(r, trialType, blockPoints);
            trial_results.isPractice = isPractice;
            trial_results.blockNum = blockNum;
            trial_results.trialInBlock = trial;
            blockPoints = blockPoints + trial_results.points;
            blockResults = [blockResults trial_results];
        end
        if isPractice
            pracString = ' practice';
        else
            pracString = '';
        end
        score = sum([blockResults.points]);
        textScreen(sprintf('End of%s block %i (of %i). Score: %i\n\nTake a short break and stretch!', pracString, blockNum, totalBlocks, score), 'wait');
    end

    function textScreen(text, how_long)
        KbQueueFlush(input_device);
        Screen('DrawTexture', stimuliScrn, t_blank);
        if strcmp(how_long, 'wait')
            extra_text = '\n\nPress button to continue.';
        else
            extra_text = '';
        end
        DrawFormattedText(stimuliScrn, [text extra_text], 'center', 'center');
        Screen('Flip', stimuliScrn);
        if strcmp(how_long, 'wait')
            KbQueueWait(input_device);
        else
            WaitSecs(how_long);
        end
    end

    function m = my_nanmedian(x)
        m = median(x(isfinite(x)));
    end
    function y = without_nan(x)
        y = x(isfinite(x));
    end
    function p = my_quantile(x, q)
        x = sort(x, 'ascend');
        n = length(x);
        k = round(n * q);
        p = x(k);
    end

    function trialResults = RunTrial(r, trialType, blockPoints)
        
        trialResults.trialType = trialType;
        
        if strcmp(trialType, 'bonus')
            Screen('DrawTexture',stimuliScrn,t_ready_bonus);
        elseif strcmp(trialType, 'regular')
            Screen('DrawTexture',stimuliScrn,t_ready_regular);
        else
            error('trialType');
        end
        Screen('Flip', stimuliScrn, 0);
        WaitSecs(params.readyScreenDuration);
        
        KbQueueFlush(input_device);
        
        % now show blank screen with moving line until signal
        Screen('DrawTexture',stimuliScrn,t_blank);
        targdelay = params.stdDelayTime * randn(r) + params.meanDelayTime;
        targdelay = max(targdelay, params.minDelayTime);
        targdelay = min(targdelay, params.maxDelayTime);
        trialResults.targdelay = targdelay;
        
        [trialResults.foreperiodonset.vbl ...
            trialResults.foreperiodonset.stimon ... 
            trialResults.foreperiodonset.flip ...
            trialResults.foreperiodonset.missed] = Screen('Flip', stimuliScrn);
        
        targetTime = trialResults.foreperiodonset.stimon + targdelay;
        progressBarLimit = trialResults.foreperiodonset.stimon + params.maxDelayTime;
        jumped_gun = 0;
        response_time = NaN;
        while 1
            [pressed, firstPressInfo] = KbQueueCheck(input_device);
            if pressed
                jumped_gun = 1;
                presses = find(firstPressInfo);
                response_time = min(firstPressInfo(presses));
                break;
            end
            % Draw vertical line
            now = GetSecs();
            Screen('DrawTexture', stimuliScrn, t_blank);
            x = (progressBarLimit - now) / (params.maxDelayTime);
            Screen('DrawLines', stimuliScrn, [w*(1-x), w*(1 - x); 0, h], 3);
            Screen('Flip', stimuliScrn);
            if now > targetTime - ifi
                break
            end
        end
        % If they haven't pressed a key, then show go signal
        if (~jumped_gun)
            Screen('DrawTexture', stimuliScrn, t_go);
            [stim_vbl stim_stimon stim_flip stim_missed] = Screen('Flip', stimuliScrn);
            % wait for button press and get response time
            response_time = KbQueueWait(input_device);
            RT = response_time - stim_stimon;
            points = GetPoints(RT, trialType, params);
            if RT < params.minResponseTime
                jumped_gun = 1;
            end
        else
            stim_vbl = NaN;
            stim_stimon = NaN;
            stim_flip = NaN;
            stim_missed = NaN;
            RT = NaN;
        end
        if jumped_gun
            % user was too early!
            Screen('DrawTexture', stimuliScrn, t_too_early);
            points = params.penaltyPoints;
            Screen('Flip', stimuliScrn);
            Beeper('low', 0.5, 0.8);
            WaitSecs(params.penaltyTime);
        end
        % Show the end-of-trial click-to-continue screen
        textScreen(sprintf('%i points!\n\nTotal this block: %i', points, blockPoints + points), params.scoreScreenDuration);
        
        trialResults.go_onset.vbl = stim_vbl;
        trialResults.go_onset.stimon = stim_stimon;
        trialResults.go_onset.flip = stim_flip;
        trialResults.go_onset.missed = stim_missed;
        
        trialResults.resp_time = response_time;
        trialResults.resp_latency = RT;
        trialResults.jumped_gun = jumped_gun;
        trialResults.points = points;

    end

end

