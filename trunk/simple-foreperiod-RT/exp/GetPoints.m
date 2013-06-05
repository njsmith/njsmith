function points = GetPoints(respTime, trialType, params)

respTime = max(0, respTime - params.minRespTime);

points = (100/params.maxScoreTime) * max(0, params.maxScoreTime - respTime);

if strcmp(trialType, 'bonus')
    points = params.bonusPoints * (respTime < params.cutoffTime);
end

points = round(points);
