function fixcross = makeFixationCross(l1, l2, l3)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Make a Fixation Cross
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fixcross(:,:,1) = l1*ones(1024, 1024);
fixcross(:,:,2) = l2*ones(1024, 1024);
fixcross(:,:,3) = l3*ones(1024, 1024);
fixcross(512:513, 257:768,:) = 0;
fixcross(257:768, 512:513,:) = 0;
end