function points = GetPoints(respTime, trialType, params)

respTime = max(0, respTime - params.minRespTime);

points = (100/params.maxScoreTime) * max(0, params.maxScoreTime - respTime);

if trialType == 2
    points = params.bonusPoints * (respTime < params.cutoffTime);
end