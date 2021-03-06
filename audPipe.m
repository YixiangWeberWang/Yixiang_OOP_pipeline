function audPipe(param)
%
%R1 11/23/17 Do Gaussian-smoothing first than top-hat 
%R2 11/24/17 Do top-hat first than do Gaussian 
%R3 11/24/17 Change the way to do df/f (Now doing intra-grouped-video df/f) see class movieData 
%R4 12/01/17 Major change to enclose parts of the code into Integration class 
%!!!NOTE THAT audPipe R4 AND HIGHER VERSIONS ARE ONLY COMPATIABLE WITH 
%movieData R6/Integration R2 AND HIGHER!!!
%R4 12/08/17 Incorporate Integration.fileDetector() see Integration.m 
%R4 12/12/17 Add spacialFactor as input 
%R5 05/25/18 Compatible with Integration R5+/movieData R8+/ROI R1+. Incorporate
%wavelength switching. This version is 
%R5 05/26/18 new input nmov to build the integration object
%R6 06/13/18 input param (struct) instead of multiple variables
%R7 10/01/18 Using parfor instead of for loop
%R8 01/04/18 Improve param passing 
%Compatiable with Integration R14 or higher!
%R8 01/15/18 save param to .mat file
    
    %If run on the HPC, use slurm to change the current directory
    try
        %currentFolder = 'E:\New folder';
        cd(currentFolder);
    catch
        disp('No such directory...Running on pwd...')
    end

    %Detect movie/baphy/spike2/roi files 
    Integration.fileDetector();
    
    %Convert spike2 raw data to .mat files
    Integration.Spike2Matlab(cd);
    
    filelist = readtext('files.txt',' ');
    nmov = size(filelist,1);
    IdxInAll = cell(nmov,1);
    IdxInAll_1 = cell(nmov,1);
    IdxInAll_2 = cell(nmov,1);
    
    %Save current parameters
    save('parameter.mat','param');
    
    %Process each movie sequentially
    parfor f = 1:nmov 
        [Idx,Idx1,Idx2] = Integration.processMovies(f,nmov,param);                   
        IdxInAll{f,1} = Idx;
        IdxInAll_1{f,1} = Idx1;
        IdxInAll_2{f,1} = Idx2;   
    end
    
    %Do averaging across all movies
    Integration.doAveragingAcrossMovies(flag,IdxInAll,IdxInAll_1,IdxInAll_2);

end


