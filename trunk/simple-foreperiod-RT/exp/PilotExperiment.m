function PilotExp


clear all
close all
tic

%% Set Up Stuff
constDelayTime = 0.500;
randDelayTime = 0.600;
fixcrossDuration = 1.000;
trialTypeDuration = 0.500;
maxResponseTime = 1.000;

% set background grey level for stimuli Screen
bkgrndGreyLevel = 100;

try
    % create stimuliScrn
    Screen('Preference', 'SkipSyncTests', 0);
    [stimuliScrn wRect] = Screen('OpenWindow', 0, bkgrndGreyLevel);
    res = wRect(3:4);
    
    % make fixation cross
    fixcross = makeFixationCross(bkgrndGreyLevel);
    t_fixcross = Screen('MakeTexture',stimuliScrn,fixcross);
    
    % blank screen
    blank = bkgrndGreyLevel*ones(1024);
    t_blank = Screen('MakeTexture',stimuliScrn,blank);
    
    % green screen
    green = bkgrndGreyLevel*ones(1024,1024, 3);
    green(:,:,2) = 200;
    t_green = Screen('MakeTexture',stimuliScrn,green);
    clear green
    
    % red screen
    red = bkgrndGreyLevel*ones(1024,1024, 3);
    red(:,:,1) = 200;
    t_red = Screen('MakeTexture',stimuliScrn,red);
    clear red
    
    % red screen
    signal = 2558*ones(1024,1024, 3);
    t_signal = Screen('MakeTexture',stimuliScrn,signal);
    clear signal
    
    
    for trial = 1:10
    % draw fixation cross
    Screen('DrawTexture',stimuliScrn,t_fixcross);
    Screen('Flip',stimuliScrn,0);
    WaitSecs(fixcrossDuration);
    
    % draw stimuli type preview (green for now)
    
    Screen('DrawTexture',stimuliScrn,t_green);
    Screen('Flip', stimuliScrn,0);
    WaitSecs(trialTypeDuration);
    
    % now show blank screen until signal
    
    Screen('DrawTexture',stimuliScrn,t_blank);
    delay = randDelayTime*rand(1) + constDelayTime;
    Screen('Flip',stimuliScrn,0);
    
    Screen('DrawTexture',stimuliScrn,t_signal);
    
    secs = -inf;
    yieldInterval = 0.005;
    untilTime = WaitSecs(0.001) + delay;
    while secs < untilTime
        [isDown, secs, keyCode] = KbCheck();
        if (isDown == 1) || (secs >= untilTime)
            break;
        end
        
        % Wait for yieldInterval to prevent system overload.
        secs = WaitSecs('YieldSecs', yieldInterval);
    end
    %% is user didn't press a key, then show signal
    if (~isDown) 
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
        R(trial,:) = [delay, secs - startTime];
    else
        % subject was too slow, so punish
     % user did press a key, so bad subject
        Screen('DrawTexture',stimuliScrn,t_red);
        Screen('Flip',stimuliScrn);
        R(trial,:) = [delay, inf];
        WaitSecs(2.5000);
    end
    else
        % user was too early!
        Screen('DrawTexture',stimuliScrn,t_red);
        Screen('Flip',stimuliScrn);
        WaitSecs(5.000);
        R(trial,:) = [delay, -inf];
    end
    
    end
    
    
    dlmwrite('resp.txt', R);

    
    Screen('CloseAll')
    
    
catch
    disp('error')
    Screen('CloseAll')
    
end


Priority(0);
toc;

end
