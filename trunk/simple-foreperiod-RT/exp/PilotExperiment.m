function PilotExperiment(subjnum, mode)

tic

% Use a repeatable random stream for each subject
r = RandStream('mt19937ar', 'seed', subjnum);
outpath = sprintf('data/resp-%03i.mat', subjnum);

% Set Up Stuff
params.stdDelayTime  = 0.200;
params.nSig = 3.5;
params.minDelayTime  = 0.050;

width = params.nSig * params.stdDelayTime;
params.meanDelayTime = params.minDelayTime + width;
params.maxDelayTime  = params.meanDelayTime + width;

params.scoreScreenDuration = 1.000;
params.readyScreenDuration = 0.750;
% If their RT is <50ms then they jumped the gun.
params.minResponseTime = 0.050;

params.trialsPerPractise = 60;
params.trialsPerBlock = 60;
params.numberOfBlocks = 10;

params.wrapChars = 70;

% points
% gun jump penalties
params.penaltyPoints = -5000;
params.penaltyTime = 5;
% normal trials
params.normalScoreTimes = [0.180 0.250];
params.normalScorePoints = [300 150];
% speedy trials
params.cutoffQuantile = 0.33;
params.chanceOfSpeedyTrial = 0.25;
params.cutoffTime = NaN; % to be set after practise trials
params.bonusSuccessPoints = 1000;
params.bonusFailurePoints = -100;
% set background grey level for stimuli Screen
% This is also used in get-ready.png, so if you change one you should
% change the other.
params.bkgrndGreyLevel = 100;
params.textColor = [0, 0, 0];

instructions1 = [ ...
    'In this experiment, your job is very simple. When you see "Go!", ' ...
    'you should press the button. ' ...
    'You should do this AS QUICKLY AS POSSIBLE. The faster you are, the higher your score. ' ...
    'The higher your score, the more money you will make at the end!\n\n' ...
    'But, be careful: if you press it BEFORE the computer says "Go!", you will lose a LOT of points! ' ...
    'Be as fast as you can once you see "Go!", but don''t be too fast!\n\n' ...
    'We''ll start with some practice; your score here won''t count.'
    ];

instructions2 = [ ...
    'Now to make things more interesting we''ll add BONUS ROUNDS. ' ...
    'In a bonus round, there is a deadline. This deadline is ALWAYS THE SAME. ' ...
    'If you''re fast enough to beat the deadline, ' ...
    'you''ll get %i points. But if you''re too slow, you get %i points! ' ...
    'It will always be obvious which rounds are bonus rounds, because they ' ...
    'have a special "Get ready!" screen.\n\n' ...
    'This next block will let you practice; your score here won''t count.' ...
    ];

instructions2 = sprintf(instructions2, params.bonusSuccessPoints, params.bonusFailurePoints);

% To get input device: GetMouseIndices, GetKeyboardIndices,
% GetGamepadIndices.
% To identify a gamepad: Gamepad('GetGamepadNamesFromIndices', indices)
input_buttons = zeros(256, 1);
if strcmp(mode(1:4), 'test')
    % Default -- keyboard
    % For some reason nothing else works on my (njs's) laptop :-( :-(
    input_device = [];
    input_buttons(KbName('space')) = 1;
    if strcmp(mode, 'test-small')
        params.trialsPerPractise = 3;
        params.trialsPerBlock = 5;
        params.numberOfBlocks = 2;
    end
elseif strcmp(mode, 'lab-gamepad')
    input_device = Gamepad('GetGamepadIndicesFromNames', 'Logitech Dual Action');
    input_buttons([5, 6]) = 1;
    Screen('Preference', 'DefaultFontSize', 36);
    Priority(9);
else
    error('unknown mode');
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
    stimuliScrn = Screen('OpenWindow', 0, params.bkgrndGreyLevel);
    [w, h] = Screen('WindowSize', stimuliScrn);
    ifi = Screen('GetFlipInterval', stimuliScrn);
    Screen('Flip', stimuliScrn);
    
    % load the various textures
    t_ready_regular = Screen('MakeTexture', stimuliScrn, imread('get-ready-regular.png'));    
    t_ready_bonus = Screen('MakeTexture', stimuliScrn, imread('get-ready-bonus-round.png'));
    t_go = Screen('MakeTexture', stimuliScrn, imread('go.png'));
    t_too_early = Screen('MakeTexture', stimuliScrn, imread('too-early.png'));
    
    disp('*starting experiment*');
    KbQueueStart(input_device);
    results = [];
    
    textScreen(instructions1, 'wait');
    results = RunBlock(r, 1, 1, 2, params.trialsPerPractise, 0, results);
    
    % calculate median response time
    disp('trying to get deadline response time');
    params.cutoffTime = my_quantile(without_nan([results(end/2:end).resp_latency]), params.cutoffQuantile);
    params.cutoffTime
    textScreen(instructions2, 'wait');
    results = RunBlock(r, 1, 2, 2, params.trialsPerPractise, 1, results);
    textScreen(['Any questions? Now''s a good time to ask them.\n\n' ...
        'Make sure you understand how the points work, because from now on, they''ll count for real!\n\n' ...
        'Otherwise, press any button when you''re ready to start the real experiment.'], 'wait');
    %% start experiment for real!
    for block = 1:params.numberOfBlocks
        results = RunBlock(r, 0, block, params.numberOfBlocks, params.trialsPerBlock, 1, results);
        save(outpath, '-v6', 'subjnum', 'results', 'params');
    end % end of a block
    non_practice_trials = [results.isPractice] == 0;
    all_points = [results.points];
    total_score = sum(all_points(non_practice_trials));
    fprintf('Total score: %i\n', total_score);
    save(outpath, '-v6', 'subjnum', 'total_score', 'results', 'params');
    textScreen('That''s all, thanks! Please notify the experimenter that you are done.', 'wait');
        
catch me
    disp('error')
    disp(me)
end

KbQueueRelease(input_device);
Screen('CloseAll');
ShowCursor();
Priority(0);

toc;

    function results = RunBlock(r, isPractice, blockNum, totalBlocks, trialCount, includeBonus, results)
        blockPoints = 0;
        for trial = 1:trialCount
            if includeBonus && (rand(r) < params.chanceOfSpeedyTrial)
                trialType = 'bonus';
            else
                trialType = 'regular';
            end
            trial_result = RunTrial(r, trialType, blockPoints);
            trial_result.isPractice = isPractice;
            trial_result.blockNum = blockNum;
            trial_result.trialInBlock = trial;
            blockPoints = blockPoints + trial_result.points;
            results = [results trial_result]; %#ok<AGROW>
        end
        if isPractice
            pracString = ' practice';
            totalString = '';
            lastBlockString = '';
        else
            pracString = '';
            if blockNum > 1
                prev_score = BlockScore(results, isPractice, blockNum - 1);
                lastBlockString = sprintf('Last time, you earned: %i points\n\n', prev_score);
            else
                lastBlockString = '';
            end
            totalString = sprintf('Your total so far: %i points\n\n', TotalScore(results));
        end
        this_score = BlockScore(results, isPractice, blockNum);       
        msg = sprintf(['That''s the end of%s block %i (of %i).\n\n' ...
            'In this block, you earned: %i points\n\n%s%s' ...
            'Take a short break and stretch!'], ...
            pracString, blockNum, totalBlocks, this_score, lastBlockString, totalString);
        textScreen(msg, 'wait');
    end

    function s = TotalScore(results)
        not_practice = ([results.isPractice] == 0);
        s = sum([results(not_practice).points]);
    end

    function s = BlockScore(results, isPractice, blockNum)
        match_practice = ([results.isPractice] == isPractice);
        match_blocknum = ([results.blockNum] == blockNum);
        scores = [results(match_practice & match_blocknum).points];
        s = sum(scores);
    end

    function textScreen(text, how_long)
        KbQueueFlush(input_device);
        if strcmp(how_long, 'wait')
            extra_text = '\n\nPress button to continue.';
        else
            extra_text = '';
        end
        DrawFormattedText(stimuliScrn, [text extra_text], 'center', 'center', params.textColor, params.wrapChars);
        Screen('Flip', stimuliScrn);
        if strcmp(how_long, 'wait')
            KbQueueWait(input_device);
        else
            WaitSecs(how_long);
        end
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
        targdelay = -inf;
        while targdelay < params.minDelayTime || targdelay > params.maxDelayTime
            targdelay = params.stdDelayTime * randn(r) + params.meanDelayTime;
        end
        trialResults.targdelay = targdelay;
        
        [trialResults.foreperiodonset_vbl ...
            trialResults.foreperiodonset_stimon ... 
            trialResults.foreperiodonset_flip ...
            trialResults.foreperiodonset_missed] = Screen('Flip', stimuliScrn);
        
        time_zero = trialResults.foreperiodonset_stimon;
        targetTime = trialResults.foreperiodonset_stimon + targdelay;
        jumped_gun = 0;
        resp_time = NaN;
        while 1
            [pressed, firstPressInfo] = KbQueueCheck(input_device);
            if pressed
                jumped_gun = 1;
                presses = find(firstPressInfo);
                resp_time = min(firstPressInfo(presses)); %#ok<FNDSB>
                break;
            end
            % Draw vertical line
            now = GetSecs();
            latency = now - time_zero;
            % Latency distribution is truncated to (minDelayTime,
            % maxDelayTime). To keep it centered on the screen, we put x=0
            % at latency=0, and x=max at latency=maxDelayTime +
            % minDelayTime.
            line_pos = w * (latency / (params.maxDelayTime + params.minDelayTime));
            Screen('DrawLines', stimuliScrn, [line_pos, line_pos; 0, h], 3);
            now = Screen('Flip', stimuliScrn);
            % Attempt to round targetTime to the nearest frame, minus 1
            % (because if we're at the targetTime - 1 frame, then we need
            % to show the target on the next frame!)
            if now + 1.5 * ifi > targetTime
                trialResults.line_pos = line_pos;
                break
            end
        end
        % If they haven't pressed a key, then show go signal
        if (~jumped_gun)
            Screen('DrawTexture', stimuliScrn, t_go);
            [stim_vbl stim_stimon stim_flip stim_missed] = Screen('Flip', stimuliScrn);
            % wait for button press and get response time
            resp_time = KbQueueWait(input_device);
            resp_latency = resp_time - stim_stimon;
            points = GetPoints(resp_latency, trialType, params);
            if resp_latency < params.minResponseTime
                jumped_gun = 1;
            end
        else
            stim_vbl = NaN;
            stim_stimon = NaN;
            stim_flip = NaN;
            stim_missed = NaN;
            resp_latency = NaN;
        end
        if jumped_gun
            % user was too early!
            Screen('DrawTexture', stimuliScrn, t_too_early);
            points = params.penaltyPoints;
            Screen('Flip', stimuliScrn);
            %Beeper('low', 0.5, 0.8);
            WaitSecs(params.penaltyTime);
        end
        % Show the end-of-trial click-to-continue screen
        textScreen(sprintf('%i points!\n\nTotal this block: %i', points, blockPoints + points), params.scoreScreenDuration);
        
        trialResults.go_onset_vbl = stim_vbl;
        trialResults.go_onset_stimon = stim_stimon;
        trialResults.go_onset_flip = stim_flip;
        trialResults.go_onset_missed = stim_missed;
        
        trialResults.resp_time = resp_time;
        trialResults.resp_latency = resp_latency;
        trialResults.jumped_gun = jumped_gun;
        trialResults.points = points;

    end

    function points = GetPoints(resp_latency, trialType, params)
        if strcmp(trialType, 'regular')
            points = interp1(params.normalScoreTimes, params.normalScorePoints, ...
                resp_latency, 'linear', 'extrap');
            points = max(0, points);
        elseif strcmp(trialType, 'bonus')
            if resp_latency < params.cutoffTime
                points = params.bonusSuccessPoints;
            else
                points = params.bonusFailurePoints;
            end
        else
            error(trialType);
        end

        points = round(points);
    end

end

