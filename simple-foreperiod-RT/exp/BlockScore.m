function s = BlockScore(results, isPractice, blockNum)
    for i = 1:length(blockNum)
        this_blockNum = blockNum(i);
        match_practice = ([results.isPractice] == isPractice);
        match_blocknum = ([results.blockNum] == this_blockNum);
        scores = [results(match_practice & match_blocknum).points];
        s(i) = sum(scores); %#ok<AGROW>
    end
end
