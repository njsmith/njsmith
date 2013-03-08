function points = GetPoints(respTime, trialType, params)

respTime = max(0, respTime - params.minRespTime);

points = (100/params.maxScoreTime) * max(0, params.maxScoreTime - respTime);

if trialType == 2
    points = points + (params.maxBonusPoints/params.bonusScoreEnd^2) * max(0, params.bonusScoreEnd - respTime).^2;
end