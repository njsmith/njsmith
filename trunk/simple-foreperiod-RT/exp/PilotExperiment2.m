function PilotExp

clear all
close all
tic

%% Set Up Stuff
constDelayTime = 0.500;
randDelayTime = 0.600;
fixcrossDuration = 1.000;
maxResponseTime = 10.000;

totalTrials = 20;
trialsPerBlock = 10;

% points
earlyPenalty = -1000;
% normal trials
params.minRespTime  = 0.075;
params.maxScoreTime = 0.700;
% speedy trials
params.chanceOfSpeedyTrial = 0.25;
params.bonusScoreEnd = 0.400;
params.maxBonusPoints = 500;
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
    for trial = 1:totalTrials
        % are we at the end of a block of trials
        if (mod(trial, trialsPerBlock) == 0) * (trial~=totalTrials)
            Screen('DrawTexture',stimuliScrn,t_blank);
            DrawFormattedText(stimuliScrn, [int2str(SCORE) ' points in total!!!\n Please press any key to continue'], 'center', 'center');
            Screen('Flip',stimuliScrn,0);
            kBWait(0);
        end
        
        % get trial type
        r = rand;
        if r < params.chanceOfSpeedyTrial
            trialType = 2;
            Screen('DrawTexture',stimuliScrn,t_important);
        else
            trialType = 1;
            Screen('DrawTexture',stimuliScrn,t_fixcross);
        end
        % draw fixation cross
        Screen('Flip',stimuliScrn,0);
        WaitSecs(fixcrossDuration);
        
        % now show blank screen until signal
        
        Screen('DrawTexture',stimuliScrn,t_blank);
        delay = randDelayTime*rand(1) + constDelayTime;
        Screen('Flip',stimuliScrn,0);
        
        secs = -inf;
        yieldInterval = 0.002;
        untilTime = WaitSecs(0) + delay;
        progressBarLimit = WaitSecs(0) + constDelayTime + randDelayTime;
        while secs < untilTime
            [isDown, secs] = KbCheck();
            if (isDown == 1) || (secs >= untilTime)
                break;
            end
            % move horizontal line
            Screen('DrawTexture',stimuliScrn,t_blank);
            x = w * (1 - (progressBarLimit-secs)/(constDelayTime + randDelayTime));
            Screen('DrawLines', stimuliScrn, [x, x ; 0, h]);%, 1, [0, 255; 0, 255; 0, 255]
            Screen('Flip',stimuliScrn);
            
            % Wait for yieldInterval to prevent system overload.
            secs = WaitSecs('YieldSecs', yieldInterval);
            

        end
        %% is user didn't press a key, then show signal
        if (~isDown)
            Screen('DrawTexture',stimuliScrn,t_signal);
            Screen('Flip',stimuliScrn);
            % now get Reaction Time
            startTime = WaitSecs(0.001);
            untilTime = startTime + maxResponseTime;
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
                respTime = secs - startTime;
                points = GetPoints(respTime, trialType, params);
                SCORE = SCORE + points;
                R(trial,:) = [trialType, delay, respTime];
                Screen('DrawTexture',stimuliScrn,t_blank);
                DrawFormattedText(stimuliScrn, [int2str(points) ' points!'], 'center', 'center');
                Screen('Flip',stimuliScrn);
                
                WaitSecs(2);
            else
                % subject was too slow, so punish
                % user did press a key, so bad subject
                Screen('DrawTexture',stimuliScrn,t_red);
                Screen('Flip',stimuliScrn);
                R(trial,:) = [trialType, delay, inf]; 
                WaitSecs(2.5000);
            end
        else
            % user was too early!
            Screen('DrawTexture',stimuliScrn,t_red);
            points = earlyPenalty;
            DrawFormattedText(stimuliScrn, ['TOO EARLY\n' int2str(points) ' points!'], 'center', 'center');
            Screen('Flip',stimuliScrn);
            WaitSecs(5.000);
            R(trial,:) = [trialType, delay, -inf];
            SCORE = SCORE + earlyPenalty;
        end
        
    end
    %% thank you screen
    
    Screen('DrawTexture',stimuliScrn,t_blank);
    DrawFormattedText(stimuliScrn, ['Thank you for taking part\n ' int2str(SCORE) ' points in total!!!'], 'center', 'center');
    Screen('Flip',stimuliScrn,0);
    kBWait(0);
    
    csvwrite('resp.txt', R);
    
    Screen('CloseAll')
    
    
catch
    disp('error')
    Screen('CloseAll')
    
end


Priority(0);
toc;

end
