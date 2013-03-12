function PilotExp

clear all
close all
tic

%% Set Up Stuff
params.stdDelayTime  = 0.200;
params.nSig = 3.5;
params.minDelayTime  = 0.050;

params.meanDelayTime = params.minDelayTime + params.nSig * params.stdDelayTime;
params.maxDelayTime  = 2*params.minDelayTime + 2*params.nSig * params.stdDelayTime;


params.fixcrossDuration = 1.000;
params.maxResponseTime = 10.000;

trialsPerBlock = 10;
numberOfBlocks = 5;
numberOfTrials = trialsPerBlock * numberOfBlocks;

practiseBlocks = 1;


R = zeros(numberOfTrials, 10);

% points
params.earlyPenalty = -1000;
% normal trials
params.minRespTime  = 0.075;
params.maxScoreTime = 0.425;
% speedy trials
params.chanceOfSpeedyTrial = 0.25;
params.cutoffTime = NaN; % to be set after practise trials
params.bonusPoints = 500;
% set background grey level for stimuli Screen
bkgrndGreyLevel = 100;


try
    % create stimuliScrn
    Screen('Preference', 'SkipSyncTests', 0);
    
    [stimuliScrn wRect] = Screen('OpenWindow', 0, bkgrndGreyLevel);
    [w, h] = Screen('WindowSize', stimuliScrn);
    ifi = Screen('GetFlipInterval', stimuliScrn);
    vbl=Screen('Flip', stimuliScrn);
    % make fixation cross
    fixcross = makeFixationCross(bkgrndGreyLevel,bkgrndGreyLevel,bkgrndGreyLevel);
    t_fixcross = Screen('MakeTexture',stimuliScrn,fixcross);
    
    % speedy screen
    important = makeFixationCross(100,255,100);
    t_important = Screen('MakeTexture',stimuliScrn,important);
    clear important
    
    % blank screen
    blank = bkgrndGreyLevel*ones(1024);
    t_blank = Screen('MakeTexture',stimuliScrn,blank);
    
    % red screen
    red = bkgrndGreyLevel*ones(1024,1024, 3);
    red(:,:,1) = 255;
    t_red = Screen('MakeTexture',stimuliScrn,red);
    clear red
    
    % signal screen
    signal = 2558*ones(1024,1024, 3);
    t_signal = Screen('MakeTexture',stimuliScrn,signal);
    clear signal
    
    disp('*starting experiment*');
    
    SCORE = 0;
    trial = 0;
    
     for block = 1:practiseBlocks
        for trialinblock = 1:trialsPerBlock
            trial = trial  + 1;
            disp('start RunTrial');
            trialData = RunTrial(1);
            disp('end RunTrial');
            R(trial,:) = trialData;          
        end % end of a trial
        % are we at the end of a block of trials
        Screen('DrawTexture',stimuliScrn,t_blank);
        DrawFormattedText(stimuliScrn, ['Please press any key to continue'], 'center', 'center');
        Screen('Flip',stimuliScrn,0);
        dlmwrite('resp.txt', R, 'precision', '%6.3f');
        kBWait(0);      
    end % end of a block
    WaitSecs(0.5);
    Screen('DrawTexture',stimuliScrn,t_blank);
    DrawFormattedText(stimuliScrn, ['Resetting score and start experiment'], 'center', 'center');
    Screen('Flip',stimuliScrn,0);
    % calculate median response time
    disp('trying to get median response time');
    params.cutoffTime =  median(R(1:(practiseBlocks*trialsPerBlock), 9)-R(1:(practiseBlocks*trialsPerBlock), 7));
    params.cutoffTime
    kbWait();
    %% start experiment for real!
    SCORE = 0;
    for block = 1:numberOfBlocks
        for trialinblock = 1:trialsPerBlock
            trial = trial  + 1;
            % get trial type
              r = rand;
              if (r>params.chanceOfSpeedyTrial)
                  type = 1;
              else
                  type = 2;
              end
            trialData = RunTrial(type);
            SCORE = SCORE + trialData(end);
            R(trial,:) = trialData;
            
        end % end of a trial
        % are we at the end of a block of trials
        
        Screen('DrawTexture',stimuliScrn,t_blank);
        DrawFormattedText(stimuliScrn, [int2str(SCORE) ' points in total!!!\n Please press any key to continue'], 'center', 'center');
        Screen('Flip',stimuliScrn,0);
        dlmwrite('resp.txt', R, 'precision', '%6.3f');
        kBWait(0);
        
    end % end of a block
    %% thank you screen
    WaitSecs(0.1);
    Screen('DrawTexture',stimuliScrn,t_blank);
    DrawFormattedText(stimuliScrn, ['Thank you for taking part\n ' int2str(SCORE) ' points in total!!!'], 'center', 'center');
    Screen('Flip',stimuliScrn,0);
    kBWait(0);
    
    Screen('CloseAll')
    
    
catch
    disp('error')
    Screen('CloseAll')
    
end

Priority(0);
toc;
dlmwrite('resp.txt', R, 'precision', '%6.3f');


    function trialData = RunTrial(trialType)
        disp(['Trial ' int2str(trial)]);
        if trialType == 2
            Screen('DrawTexture',stimuliScrn,t_important);
        else
            trialType = 1;
            Screen('DrawTexture',stimuliScrn,t_fixcross);
        end
        % draw fixation cross
        Screen('Flip',stimuliScrn,0);
        WaitSecs(params.fixcrossDuration);
        
        % now show blank screen until signal
        Screen('DrawTexture',stimuliScrn,t_blank);
        delay = params.stdDelayTime * randn(1) + params.meanDelayTime;
        delay = max(delay, params.minDelayTime);
        delay = min(delay, params.maxDelayTime);
        
        [t1a t1b t1c] = Screen('Flip',stimuliScrn,0);
        
        secs = -inf;
        yieldInterval = 0.002;
        untilTime = WaitSecs(0) + delay;
        progressBarLimit = WaitSecs(0) + params.maxDelayTime;
        while secs < untilTime
            [isDown, secs] = KbCheck();
            if (isDown == 1) || (secs >= untilTime)
                break;
            end
            % move horizontal line
            Screen('DrawTexture',stimuliScrn,t_blank);
            x = (progressBarLimit-secs)/(params.maxDelayTime);
            Screen('DrawLines', stimuliScrn, [w*x, w*x ; 0, h], 3);%, 1, [0, 255; 0, 255; 0, 255]
            Screen('DrawLines', stimuliScrn, [w*(1-x), w*(1-x) ; 0, h], 3);
            Screen('Flip',stimuliScrn);
            
            % Wait for yieldInterval to prevent system overload.
            secs = WaitSecs('YieldSecs', yieldInterval);
        end
        %% is user didn't press a key, then show signal
        if (~isDown)
            Screen('DrawTexture',stimuliScrn,t_signal);
            [t2a t2b t2c] = Screen('Flip',stimuliScrn);
            % now get Reaction Time
            startTime = WaitSecs(0.001);
            untilTime = startTime + params.maxResponseTime;
            while secs < untilTime
                [isDown, secs, ~] = KbCheck();
                if (isDown == 1) || (secs >= untilTime)
                    break;
                end
                % Wait for yieldInterval to prevent system overload.
                secs = WaitSecs('YieldSecs', yieldInterval);
            end
            
            if isDown
                % subect replied in time, save result
                respTime = secs;
                points = GetPoints(respTime-startTime, trialType, params);
                Screen('DrawTexture',stimuliScrn,t_blank);
                DrawFormattedText(stimuliScrn, [int2str(points) ' points!'], 'center', 'center');
                Screen('Flip',stimuliScrn);
                WaitSecs(2);
            else
                % subject was too slow, so punish
                % user did press a key, so bad subject
                Screen('DrawTexture',stimuliScrn,t_red);
                Screen('Flip',stimuliScrn);
                respTime = inf;
                points = 0;
                WaitSecs(2.5000);
            end
        else
            % user was too early!
            Screen('DrawTexture',stimuliScrn,t_red);
            points = params.earlyPenalty;
            DrawFormattedText(stimuliScrn, ['TOO EARLY\n' int2str(points) ' points!'], 'center', 'center');
            Screen('Flip',stimuliScrn);
            respTime = -inf;
            t2a = NaN; t2b = NaN; t2c = NaN;
            WaitSecs(5.000);
            
        end
        trialData = [trialType, delay, t1a t1b t1c t2a t2b t2c respTime, points];
    end

end

