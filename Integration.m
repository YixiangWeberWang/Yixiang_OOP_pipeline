classdef Integration < spike2 & baphy & movieData & Names & ROI & wlSwitching
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Test
%Integration is a subclass that inherits from all superclasses to
%analyze auditory experiment data. Specifically, Integration inherits
%from spike2\baphy\movidData\Names\ROI\wlSwitching classes
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Warning:
%Change backslashes in any path to forwardslashes when running on HPC!!! 
%Warning lifted:
%05/28/18 now the program can handle both cases (UNIX or WINDOWS syntax)    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%R2 12/01/2017 Add a pipeline processing function to differentially
%process different data sets (for future spontaneous experimental set-up
%and stimuli-evoked set-up) 
%!!!NOTE THAT INTEGRATION R2 AND HIGHER ARE ONLY COMPATIABLE WITH 
%movieData R6 AND HIGHER!!!
%R3 12/08/2017 Add fileDetector function to allow automatically txt files
%generation 
%R3 12/08/2017 Add try catch module to tackle idx mismatch 
%R4 12/08/2017 Impose dFOverF to tophat filtered matrix 
%R4 12/12/2017 Add function minSpotSize to compute the minimum size of CC
%to be preserved. 
%R4 12/12/2017 Move makeCCMovie function to static 
%R4 05/23/2018 Tolerant to inperfect movie recording (when less than 6000
%frames were recorded) 
%R5 05/24/2018 New superclass wlSwitching. New static functions
%processMovies, doAveragingAcrossMovies. Compatible with audiPipe
%R5+/movieData R8+/ROI R1+/wlSwitching R1+.   This version is R5
%R5 05/25/2018 Store nmov as a class properties (for direct input to the 
%function AverageAcrossMovies in superclass movieData 
%R5 To better deal with file-separator problem in Unix v.s. Windows use
%fullfile function 
%R6 05/31/18 To adapt with different baphy configurations (different baphy 
%trail blocks and movie frames)  
%R7 06/06/18 Compatiable with ROI class R2, movieData R9           
%R8 06/13/18 Modify prePipe function, compatiable with movieData R10 
%(rigid registration and photo bleaching correction)                           
%R9 06/19/18 Add SVD denosing comopatiable with movieData R11
%R9 07/01/18 Modify the GenerateCC function; Convert 0 values to nan after
%top-hat filtering 
%R10 07/07/18 Major improvement of how to generate connected components
%Use 2D properties (eccentricity and orientation) of ellipse to filter CCs
%Modify 3D filtering of CCs (at least last for 3 consecutive frames)
%New function filterCC_byFrame. Save BW_ppA. 
%R10 07/09/18 New function: fileDetector_keyword(keyword)
%R10 07/09/18 Now compatiable with spontaneous wavelength switching
%Taking advantage of the ME.identifier == 'MATLAB:unassignedOutputs'.
%R10 07/10/18 If filtered matix exist, skip pre-processing. Change range of
%orientation to be preserved (save those within 15-75 degree range)
%R11 10/02/18 renewCC function is moved from the byPassPreProcessing.m to
%the Integration class. Also now renewCC can output number of connected
%components within each minutes of the movie (by a seperate function 
%minuteFreqCC) in the Integration class. Compatible with
%byPassPreProcessing R3 or higher versions.
%R12 10/15/18 Apply top-hat filter to the movie depends on different scenarios
%Also modify
%R13 12/28/18 Change the preprocessing filters order 
%R13 01/03/18 Modified roiSVD function in movieData
%R13 01/03/18 Improved roi-masking after downsampling
%R14 01/04/18 Improved param passing 
%Compatiable with audPipe R8 or higher!
%R14 01/08/18 Added ICA analysis
%R15 01/20/18 Added movement assessment. Only Compatible with movieData R19+
%R16 01/24/18 Added readSingleMatrix function. Only compatible with
%byPassProcessing R6+
%R17 01/26/2018 Added new property to Integration class. Added focusOnRoi
%procedure after apply ROI mask. Saved the downsampled small mask to obj.
%Save the obj at the end of the processing. Only comptible with ROI R6+ and
%movieData R21+
%R18 01/30/2018 Changed the way to day rigid registration. Only compatible
%with movieData R22+
%R19 01/31/2018 Changed preprocessing order, allowing movement adjustment
%and dFoF after SVD denosing. Compatiable with byPassPreProcessing R7+
%R19 Update the way to generate fixed_frame before doing image registration
%R20 02/07/2018 Update rigid registration procedures 
%R21 03/03/2019 Major updation: do gaussian smoothing right after
%downsampling. Improve movement assessment function. Only compatible
%with movieData R23+
%R22 04/28/2019 Using movAsessUsingEdge. Update GenerateCC function
%compatible with movieData R26+
%R23 05/03/2019 Modify the prePipe configuration so ouputs of different
%movAssess functions will not ocerwrite each other. Use pre-processed
%movied from saved instance mat file. Compatiable with byPassProcessing R8+
%R24 06/04/19 Update preprocessing procedures. Use new discrete FFT based
%registration. Only compatible with movieData R27+
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    properties
        flag; %0, for spontaneous activity without stimuli; 1, for activity with stimuli; 2, for wavelength switching 
        nmov; %Number of movies
        smallMask; %Mask that conform to downsampled ROI-applied movie
    end
    
    methods
        function obj = Integration(f,flag,nmov)
        %Integration object constructor
            
            if nargin == 1
                %With external stimulation
                flag = 1;
                disp('Assuming Spike2 and Bahpy files are provided')
            end
            
            %Get corresponding file names 
            Namesobj = Names(f,flag);
            filename = Namesobj.filename;
            Spike2name = Namesobj.Spike2name;
            Baphyname = Namesobj.Baphyname;
            Audioname = Namesobj.Audioname;
            ROIname = Namesobj.ROIname;
          
            %Wavelength switching
            if flag == 2
                movieObj = movieData(filename,1); A_ = movieObj.A; %Here if input flag == 2, will not further process
                ROIObj = ROI(); ROI_ = ROIObj.ROIData; %Here if input flag == 2, will not further process
            else
                A_ = []; ROI_ = [];
            end           
            
            %To get blcokN for spike2 object construction
            baphyObj = baphy(Baphyname);
            
            %Subclass objects construction
            obj@Names(f,flag);
            obj@movieData(filename,flag);
            obj@spike2(Spike2name,baphyObj.blockN);
            obj@baphy(Baphyname);
            obj@ROI();
            obj@wlSwitching(flag,A_,ROI_);
          
            obj.flag = flag;
            obj.nmov = nmov;
            
            clear movieObj ROIObj Namesobj baphyObj
          
        end
        
        function FramesByFreqVolu = prePipe(obj,param)
        
        %    Preprocessing pipeline to handle a single auditory project
        %    movie. Process includes: photobleaching correction,
        %    rigid registration, applying ROI masks, downsampling,
        %    top-hat filtering, frequency-frame alignment(optional),
        %    frequency-volume maps plotting(optional),gaussian smoothing, 
        %    black-white thresholding, connected component extraction etc.            
        %    
        %    Inputs:
        %        obj               current object
        %        param             parameter struct to feed in different
        %                          function
        %   
        %   Outputs:
        %        FramesByFreqVolu  sorted frames by frequency and volume
        
            currentFolder = pwd;
            filename = obj.filename;        
            disp(['Processing: ' filename]);
            disp(' ');
 
            outputFolder = fullfile(currentFolder,obj.outputFolder); 
            mkdir(outputFolder);
            
            if obj.flag
            %Try to do frame-frequency alignment if flag == 1;
            %For spontaneous cases this step will be skipped.
                try
                    FramesByFreqVolu = obj.FramesByFreqAlign;
                catch ME
                    %Handle damaged spike2 files problem
                    if (strcmp(ME.identifier,'MATLAB:badsubscript'))
                        disp('')
                        disp('Index exceeds matrix dimensions. Check Spike2!!')
                        disp('Skip alignment...')
                        disp('')
                    elseif (strcmp(ME.identifier,'MATLAB:unassignedOutputs'))
                        disp('')
                        disp('Unassigned Outputs, probably baphy file not provided. Skip alignment...')
                        disp('')
                    end
                    obj.flag = ~obj.flag;
                    FramesByFreqVolu = 0;
                end
            else
                FramesByFreqVolu = 0;
            end


            %If instance matrix exsits, load the object/instance
            checkname = [filename(1:length(filename)-4) '_instance.mat'];
            if exist(fullfile(outputFolder,checkname),'file')
                %Load the downsampled movie from the object
                disp('Instance matrix detected, skip pre-processing...')
                curLoad = load(fullfile(outputFolder,checkname));
                curObj = curLoad.obj;
                A_DS = curObj.A;
                clear curObj;
            else                    
                %If instance matrix not detected, create one
                
                %Correct photobleaching
                A_corrct = Integration.bleachCorrection(obj.A);
                obj.A = [];
                disp('Photobleaching corrected!');

                %Gaussian smoothing
                A_corrct = Integration.GauSmoo(A_corrct,1); %set sigma = 1
                disp('Gaussian smoothing is done');
                disp(' ')

                %Apply ROI mask(s)
                A_ROI = Integration.ApplyMask(A_corrct,obj.ROIData);
                disp('Successfully apply ROI')
                clear A_corrct

                %Focusing on just the ROI part of the movie
                A_ROI = movieData.focusOnroi(A_ROI);

                %Downsampling
                A_DS = Integration.downSampleMovie(A_ROI,param.spacialFactor);
                disp(['Successfully downsample by factor of ' num2str(param.spacialFactor)])
                clear A_ROI

                %"Raw" data stored in the object
                obj.A = A_DS;
                
                %Get the downsampled roi mask
                ds_Mask = repmat((A_DS(:,:,1) ~= 0),[1,1,size(A_DS,3)]);
                obj.smallMask = ds_Mask(:,:,1);
                
                %Save the instance as an object
                checkname = [filename(1:length(filename)-4) '_instance.mat'];
                save(fullfile(outputFolder,checkname),'obj','-v7.3');
            end

            %Get the downsampled roi mask
            ds_Mask = repmat((A_DS(:,:,1) ~= 0),[1,1,size(A_DS,3)]);

            %Top-hat filtering
            if ~obj.flag
                %TH_A = Integration.TopHatFiltering(A_DS);
                TH_A = A_DS;
                %disp('Top-hat filtering is done');
                disp('Not doing top-hat filtering here')
            else
                sz = size(A_DS); se = strel('rectangle',[sz(1)*2,sz(2)]*2);
                TH_A = imtophat(A_DS, se);
                disp('For stimulation experiments, not doing top-hat filtering in time dimmension')
                disp('')
            end
            clear A_DS

            %ICA analysis of the matrix
            try
                [icasig, M, W, corr_map] = movieData.getICA(TH_A);
                checkname = [filename(1:length(filename)-4) '_ICA.mat'];
                save(fullfile(outputFolder,checkname),'icasig', 'M', 'W', 'corr_map')
            catch
                disp('ICA analysis failed')
            end             

            %Assess movement, doing translation registration at the
            %same time
            if param.moveAssessFlag
                %Save as different filenames when discarding frames
                movTag = 'dsc';
            else
                movTag = '';
            end
            
            [A_registered,tform_all,NormTform_all] = ...
            movieData.movAssess(TH_A, param.moveAssessFlag);
        
            clear TH_A
            checkname = [filename(1:length(filename)-4) '_moveAssess' movTag '.mat'];
            save(fullfile(outputFolder,checkname),'tform_all','NormTform_all');
            
            %Centered data around origins
            A_mean = nanmean(A_registered,3);
            A_registered = A_registered - A_mean;

            %SVD denosing of down-sampled A
            try 
                iniDim = param.iniDim;
            catch
                iniDim = 1; param.iniDim = iniDim;
            end
            %iniDim = iniDim + iniDimFlag;
            [de_A,U,S,V,iniDim] = Integration.roiSVD(A_registered, iniDim);
            %Reaply downsampled roi mask
            de_A = de_A.*ds_Mask;
            de_A(de_A == 0) = nan;
            checkname = [filename(1:length(filename)-4) '_SVD.mat'];
            save(fullfile(outputFolder,checkname),'U','S','V','param','iniDim');
            disp('SVD denosing is done')
            disp('')
            clear A_registered

            %Recover the data, this is important for later dFoF
            de_A = de_A + A_mean;

           %Impose dFOverF to downsampled matrix
            ds_Mask = ds_Mask(:,:,1:size(de_A,3));
            de_A = de_A.*ds_Mask;
            de_A(de_A == 0) = nan;
            A_dFoF = Integration.grossDFoverF(de_A);
            A_dFoF = A_dFoF.*ds_Mask;
            clear A_registered
            disp('Gloabal dFoverF is done')
            disp(' ')                            

            %Z-scoring de_A along the time dimension
            %de_A = zscore(de_A,1,3);
            %disp('Z-scored reconstructed matrix')

            %Check flag to decide whether to generate frequency/volume maps
            if obj.flag
                %Integration.FreqColorMap(TH_A,filename,obj);
                A_dFoF(A_dFoF == 0) = nan; % for better intra-Video dFOverF
                Integration.FreqVoluColorMap(A_dFoF,filename,obj.nmov);
                %de_A(isnan(de_A)) = 0; %resume for later filtering
            end

            %Save filtered matrix
            checkname = [filename(1:length(filename)-4) '_filtered' movTag '.mat'];
            save(fullfile(outputFolder,checkname),'A_dFoF','-v7.3');

            if obj.flag == 0 %compute connected components only for spontaneous case
                %For later analysis, only focus on ROI part
                ppA_roi = movieData.focusOnroi(A_dFoF); %ppA: pre-processed A
                
                %Generate connected components using renewCC function
                Integration.renewCC(ppA_roi,outputFolder,filename)
            end
            clear A_dFoF ppA_roi
            
            disp(['Preprocessing done: ' filename]);
            disp('')
        end
        
       
        
        function FramesByFreqVolu = FramesByFreqAlign(obj)
        
        %    Align frames by frequencies being presented.
        %    
        %    Inputs:
        %        obj     Current object
        %    
        %    Outputs:
        %        .mat files that store ouput data 
        %       
         
                               
            filename = obj.filename;
            Idx_baphstar = obj.Idx_baphstar;
            Idx_framesEy = obj.Idx_framesEy;
            savename = [filename(1:length(filename)-4),'_Spike2BaphyIndex.mat'];
          
            %Handle imperfect recording, preserve good trails
            ActualTrailNumber = min([size(Idx_baphstar,2),size(obj.txt_line,1),floor(size(obj.A,3)/40)]);
            disp(['[Baphstar,txt_line,A_size3]= ' num2str([size(Idx_baphstar,2),size(obj.txt_line,1),floor(size(obj.A,3)/40)])])
            disp(['Usable Trails = ' num2str(ActualTrailNumber)]);
            txt_line = obj.txt_line(1:ActualTrailNumber,:);
            [freq,volu] = Integration.GetVoluFreq(txt_line);
            obj.freq = freq;
            obj.volu = volu;
            
            %Remove extra indices from spike2 if it goes beyond the actual
            %movie frames
            Idx_baphstar = Idx_baphstar(:,1:ActualTrailNumber); 
            Idx_framesEy = Idx_framesEy(:,1:40*ActualTrailNumber);
            
            Idx_baphstar(3,:) = freq';
            Idx_baphstar(4,:) = volu';

            %Whether camera frames are enclosed by squrewaves
            for t = 1:size(Idx_framesEy,2)

                if Idx_baphstar(2,1)<Idx_framesEy(1,t)
                    Idx_baphstar(:,1) = [];
                end
                if Idx_baphstar(1,1)<Idx_framesEy(1,t) && Idx_baphstar(2,1)>Idx_framesEy(1,t)
                    Idx_framesEy(2,t) = Idx_baphstar(3,1);
                    Idx_framesEy(3,t) = Idx_baphstar(4,1);
                end

            end
            
            %For some rare cases, seems that camera frames are present
            %prioir to baphstar square waves. Debug this problem here
            tmp_id = find(~Idx_framesEy);
            for i = 1:length(tmp_id)
                Idx_framesEy(tmp_id(i)) = Idx_framesEy(tmp_id(i)+3);
            end

            save(savename,'Idx_framesEy');
            
            %Get list of frequencies and volumes that have been presented
            FreqList = unique(freq);
            VoluList = unique(volu);

            if exist('FreqVoluList.mat')
                load('FreqVoluList.mat')
                FreqVoluList{size(FreqVoluList,1)+1,1} = FreqList;
                FreqVoluList{size(FreqVoluList,1)+1,1} = VoluList;
                save('FreqVoluList.mat','FreqVoluList')
                %fprintf('exsit \n')
            else
                FreqVoluList = {};
                FreqVoluList{1,1} = FreqList;
                FreqVoluList{2,1} = VoluList;
                save('FreqVoluList.mat','FreqVoluList');
                %fprintf('new \n')
            end
            
            %Construct FramesByFreq that store sorted frames (by freq)
            FramesByFreq = cell(2,size(FreqList,1));
            for k = 1 : size(FreqList,1)
                FramesByFreq{1,k} = FreqList(k,1);
                FramesByFreq{2,k} = find(Idx_framesEy(2,:) == FreqList(k,1))';
            end
            FreqFilename = [filename(1:length(filename)-4),'_FramesByFreq.mat'];
            save(FreqFilename,'FramesByFreq');


            %Construct FramesByFreq that store sorted frames (by freq&volu)
            FramesByFreqVolu = cell(size(VoluList,1),size(FreqList,1));
            for i = 1 : size(FreqList,1)
                temp_Idx1 = find(Idx_framesEy(2,:) == FreqList(i,1));
                for j = 1: size(VoluList,1)
                    temp_Idx_framesEy = [temp_Idx1; Idx_framesEy(2:3,temp_Idx1)];
                    temp_Idx2 =(temp_Idx_framesEy(3,:) == VoluList(j,1));
                    FreqVoluSpecIdx_framesEy = temp_Idx_framesEy(:,temp_Idx2);
                    temp_block = [FreqVoluSpecIdx_framesEy(2,1);FreqVoluSpecIdx_framesEy(3,1);...
                        FreqVoluSpecIdx_framesEy(1,:)'];
                    FramesByFreqVolu{j,i} = temp_block;
                end
            end
            FreqVoluFilename = [filename(1:length(filename)-4),'_FramesByFreqVolu.mat'];
            save(FreqVoluFilename,'FramesByFreqVolu');


        end
                     
    end
    
    
    methods(Static)
        
        function A3 = makeCCMovie(filename,CC,sz)
        %make connected component movie
            A3 = false(sz);           
            for i = 1:CC.NumObjects
                A3(CC.PixelIdxList{i}) = true;
            end
            M(size(A3,3)) = struct('cdata',[],'colormap',[]);
            for fr=1:size(A3,3)
                [I2, map] = gray2ind(A3(:,:,fr), 8); %figure; imshow(I2,map)
                M(fr) = im2frame(I2,map);
            end
            writeMovie(M,filename(1:length(filename)-4));
        end
        
        function CC = ccThresh_3D(CC,minSpotSize)
        
        %    Thresholding the connected componnents based on each
        %    component's size and temporal duration
        %    
        %    Inputs: 
        %       CC     Connected components from bwconncomp
        %       miniSpotSize    Thresholding size factor
        %
        %   Outputs:
        %      CC     Renewed CC
        
            CC = Integration.ccSizeThresh(CC,minSpotSize);
            CC = Integration.ccTimeThresh(CC);
        end
        
        
        function CC = ccSizeThresh(CC,minSpotSize)
        
        %    Thresholding the CC based on length of each PixelIdxList
        %    If length is smaller than minimum spot size, kill it.
        %    
        %    Inputs: 
        %    CC     Connected components from bwconncomp
        %    miniSpotSize    Thresholding size factor
        %
        %    Outputs:
        %    CC     Renewed CC
        
            sz = cellfun(@length,CC.PixelIdxList);
            %minSpotSize = prctile(sort(sz),90);
            kill = sz<minSpotSize;
            CC.PixelIdxList(kill) = [];
            CC.NumObjects = length(CC.PixelIdxList);     
        end
        
        
        function CC = ccTimeThresh(CC, durT)
        
        %    Thresholding the CC based on each component's temporal
        %    duration, which is the length of the BoundingBox side along the
        %    time dimension. A component should last for at least 3 frames
        %   
        %    Inputs:
        %    CC     Connected components from bwconncomp
        %    durT   duration threshold
        %
        %    Outputs:
        %    CC     Renewed CC
        
            if nargin < 2
                durT = 3;
            end
            %disp(['Duration threshold = ' num2str(durT)])
        
            STATS = regionprops(CC,'Area','BoundingBox');
            roiBoundingBox = zeros(length(STATS),6);
            for i = 1:length(STATS)
                roiBoundingBox(i,:) = STATS(i).BoundingBox;
            end
            durations = roiBoundingBox(:,6);
            newPixelIdxList = CC.PixelIdxList;
            
            %duration should be larger/equal to 3 frames
            newPixelIdxList(durations(:) < durT) = [];
            CC.PixelIdxList = newPixelIdxList;
            CC.NumObjects = length(newPixelIdxList);                 
        end
        
        
        function fileDetector()
        
        %    Generate txt files based on file detected. Generate files.txt as a list
        %    of names of .tif movies. Generate Spike2files.txt as a list of names of 
        %    .mat spike2 data. Generat baphyfiles.txt as a list of names of baphy
        %    files. 
        %    
        %    Warning: The filenames of spike2/tif moives/baphys should be in
        %    a descending order accordingly. Otherwise the matching will be
        %    incorrect!!!
        

            tmp_list = dir;
            screen_types = {'.mat','.m','.tif'};
            disp(['Working Folder: ' pwd])
            tifID = fopen('files.txt','w+');
            spike2ID = fopen('Spike2files.txt','w+');
            baphyID = fopen('baphyfiles.txt','w+');

            for i = 1 : length(tmp_list)

                curName = tmp_list(i).name;
                
                %skip '.' and '..'
                if length(curName) < 2
                    continue
                end

                last2chars_name = curName(end-1:end);
                count = 0;
                flag = false;
                
                %Write in different .txt files according to the type of the
                %detected files
                while (count < length(screen_types))&&(~flag)
                    count = count + 1;
                    curr_type = screen_types{count};
                    last2chars_type = curr_type(end-1:end);

                    if last2chars_name == last2chars_type
                        flag = true;
                        switch curr_type
                            case '.mat'
                                fprintf(spike2ID,'%s\r\n',curName);
                            case '.m'
                                fprintf(baphyID,'%s\r\n',curName);
                            case '.tif'
                                if isempty(strfind(curName,'@00'))
                                    fprintf(tifID,'%s\r\n',curName);
                                end
                        end
                    end

                end
            end

            fclose('all');
        end
        
        function filelist = fileDetector_keyword(keyword)
        % Detect files whose names contain the provided keyword
        % Inputs:
        %   keyword     string for regexp function
        %
        % Outputs:
        %   filelist    List of qualified files
        %
            if nargin == 0
                disp('No key string provided!')
                keyword = '.';
            end

            temp_info = dir;
            filelist = {};
            n = 0;
            for i = 1:size(temp_info,1)  
                if regexp(temp_info(i,1).name,keyword)
                    n = n+1;
                    filelist{n,1} = temp_info(i,1).name;
                end
            end
        end
        
        function minSize= minSpotSize(CC)
        
        %    Compute the minimum size of CC to be preserved. 
        %
        %    Inputs:
        %        CC      connected components
        %                %
        %    Outputs:
        %        minSize     minimum size chosen for thresholding
        
            
            PixelIdxList = CC.PixelIdxList;
            sizeCounts = cellfun(@length,PixelIdxList);
            %Choose the bigger one btw 20% percentile of all CC sizes and 0.1% of image size 
            sz = CC.ImageSize;
            minSize = max(prctile(sizeCounts,20),sz(1)*sz(2)/1000);
        
        end
        
        function [Idx,Idx1,Idx2] = processMovies(f,nmov,param)
        
        %    Proccess movies (called by audPipe) seuqentially. This can
        %    handle different scenarios providing different flags.
        %    
        %    Inputs:
        %        f      The f-th movie to process
        %        param  parameters that users feed in
        %        
        %    Outputs:
        %        Idx,Idx1,Idx2    Frames indices sorted by frequencies or volume
        
            Idx = []; Idx1 = []; Idx2 = [];
            flag = param.flag;
            if flag == 2
                IntgA = Integration(f,flag,nmov);
                IntgA.A = [];
                IntgA.ROIData = [];
                
                %Do channel 1 
                IntgA.A = IntgA.A1;
                IntgA.ROIData = IntgA.ROI1;
                IntgA.ROI1 = [];
                IntgA.A1 = [];
                currentFolder = pwd;
                newFolder = fullfile(currentFolder,'Channel_1');
                if ~exist(newFolder,'dir')
                    mkdir(newFolder);
                end
                cd(newFolder)
                Idx1 = IntgA.prePipe(param);
                cd(currentFolder);      
                fprintf(['No.' num2str(f) ' Channel 1 is finished\n']);

                %Do channel 2
                IntgA.A = IntgA.A2;
                IntgA.ROIData = IntgA.ROI2;
                IntgA.ROI2 = [];
                IntgA.A2 = [];
                currentFolder = pwd;
                newFolder = fullfile(currentFolder,'Channel_2');
                if ~exist(newFolder,'dir')
                    mkdir(newFolder);
                end
                cd(newFolder)
                Idx2 = IntgA.prePipe(param);
                cd(currentFolder);   
                fprintf(['No.' num2str(f) ' Channel 2 is finished\n']);

                clear IntgA;

            else
                %Single channel recording
                IntgA = Integration(f,flag,nmov);
                Idx = IntgA.prePipe(param);              
                fprintf(['No.' num2str(f) ' is finished\n']);
                disp('');
                clear IntgA;
            end
        end

        function doAveragingAcrossMovies(flag,IdxInAll,IdxInAll_1,IdxInAll_2)
        
        %    Average across different movies with the AveragedMatrix_ mat
        %    files. This can handle different scenarios providing different flags.
        %    
        %    Inputs:
        %        flag   Represents different experimental setups  
        %        IdxInALL,IdxInAll_1,IdxInAll_2    Indices of sorted frames
            
        

            if flag == 2
                %Channel 1
                currentFolder = pwd;
                Folder1 = fullfile(currentFolder,'Channel_1');
                cd(Folder1)
                Integration.AveragedMapsAcrossMovies();
                savename = 'IdxInAll_1';
                save(savename,'IdxInAll_1');

                cd(currentFolder);   
                
                %Channel 2
                currentFolder = pwd;
                Folder2 = fullfile(currentFolder,'Channel_2');
                cd(Folder2)
                Integration.AveragedMapsAcrossMovies();
                savename = 'IdxInAll_2';
                save(savename,'IdxInAll_2');
                cd(currentFolder);
            else
                %Single channel recording
                Integration.AveragedMapsAcrossMovies();
                savename = 'IdxInAll';
                save(savename,'IdxInAll')
            end
        end
        
        
        function BW_ppA = filterCC_byFrame(BW_ppA)
            
        % Use 2D propertity of each frame (size, eccentricity, orientation)
        % to filter connected components and reconstruct the binary movie
        %
        % Input/Output:
        %   BW_ppA          Binary 3D matrix
        
            sz = size(BW_ppA);
                for i = 1:sz(3)

                    cur_img = BW_ppA(:,:,i);
                    cur_CC = bwconncomp(cur_img);

                    %Filter by size
                    szList = cellfun(@length,cur_CC.PixelIdxList);
                    kill_sz= szList< sz(1)*sz(2)/1000;
                    cur_CC.PixelIdxList(kill_sz) = [];
                    cur_CC.NumObjects = length(cur_CC.PixelIdxList);

                    %Filter by ellipse properties
                    leftBound = round(size(cur_img,2)/2);
                    rightBound = round(size(cur_img,2)/2);

                    cur_STATS = regionprops(cur_CC,'Eccentricity','Orientation','Centroid'); 
                    kill_eclipse = zeros(1,length(cur_STATS));
                    for j = 1:length(cur_STATS)
                        cur_struct = cur_STATS(j);

                        if  cur_struct.Eccentricity < 0.6 %filter by eccentricity
                            kill_eclipse(1,j) = 1;
                        else
                            if (cur_struct.Centroid(1) < leftBound) %for bands on the left 1/3, specify reasonable orientation range
                                if (cur_struct.Orientation < -75)||(cur_struct.Orientation > -15)
                                    kill_eclipse(1,j) = 1;
                                end
                            elseif (cur_struct.Centroid(1) > rightBound) %for bands on the right 1/3, specify reasonable orientation range
                                if (cur_struct.Orientation > 75)||(cur_struct.Orientation < 15)
                                    kill_eclipse(1,j) = 1;
                                end
                            end
                        end        
                    end

                    cur_CC.PixelIdxList(logical(kill_eclipse)) = [];
                    cur_CC.NumObjects = length(cur_CC.PixelIdxList); 

                    %Reconstruct filtered image
                    x = [];
                    for k = 1:length(cur_CC.PixelIdxList)
                        cur_cell = cur_CC.PixelIdxList(k); 
                        x = [x;cur_cell{1}];
                    end
                    rcs_img = zeros(sz(1),sz(2));
                    rcs_img(x) = 1;
                    BW_ppA(:,:,i) = rcs_img;
                end

        end
        
        
        function [region,BW_ppA] = GenerateCC(ppA,BW_ppA,frameFlag,timeFlag,durT)
        
        %    Generate connected components from pre-processed matrix
        %    
        %    Inputs:
        %        ppA     Matrix that has been pre-processed
        %        BW_A    Matrix that has been black-white thresholded
        %        filename   current filename
        %        frameFlag  whether filtering by frame properties
        %        timeFlag   whether filtering by duration
        %        durT       duration threshold
        %
        %    Outputs:
        %        region  store all region properties
        %        BW_ppA  filtered blakc-white matrix
            
            if nargin<3
                frameFlag = 1;
                timeFlag = 1;
                durT = 3;
            end
            
            %Connected components of thresholded A.
            disp('Processing Connected Components and Regionprops')
            disp('')
            
            %Filter BW_ppA by frame using 2D properties of the CCs
            if frameFlag
                BW_ppA = Integration.filterCC_byFrame(BW_ppA);
            end
            
            %Filter BW_ppA using the 3D properties of the CCs
            CC = bwconncomp(BW_ppA);
            %minSize = Integration.minSpotSize(CC);
            %CC = ccThresh_3D(CC,minSpotSize)
            if timeFlag
                CC = Integration.ccTimeThresh(CC, durT);
            end
            STATS = regionprops(CC,ppA,'Area','BoundingBox', 'Centroid',...
                'MaxIntensity', 'MinIntensity', 'MeanIntensity');
            %Integration.makeCCMovie(filename,CC,sz);
            
            %Reconstruct filtered image
            x = [];
            for k = 1:length(CC.PixelIdxList)
                cur_cell = CC.PixelIdxList(k); 
                x = [x;cur_cell{1}];
            end
            rcs_movie = zeros(size(BW_ppA));
            rcs_movie(x) = 1;
            BW_ppA = rcs_movie;

            %Store connected components and regionprops STATS
            region.CC = CC;
            region.STATS = STATS;
        end
        
        
        function minuteFreqCC(BW_ppA,ppA_roi,outputFolder,filename)            
        %   Compute connected components within each minutes of the movie
        %
        %   Inputs:
        %       BW_ppA     pre-processed matrix black and white movie
        %       outputFolder     folder that users define to save the oupputs
        %       filename    filename from which current matrix is read in
        %
        %   Outputs:
        %       .mat files that store the information average/standard
        %       deviation of number of bands within 1 minutes of the movie
        
            iterN = ceil(size(BW_ppA,3)/600); %Number of iteration
            CC_freq = [];       
            for i = 1 : iterN
                frame_ini = (i-1)*600 + 1;
                frame_end = i*600;           
                %Sample each minutes of the movie
                try
                    sub_BW_ppA = BW_ppA(:,:,frame_ini:frame_end);
                    sub_ppA = ppA_roi(:,:,frame_ini:frame_end);
                    frameN = 600;
                catch
                    sub_BW_ppA = BW_ppA(:,:,frame_ini:end);
                    sub_ppA = ppA_roi(:,:,frame_ini:end);
                    frameN = size(BW_ppA,3) - frame_ini + 1;
                end
                %Calculate CCs within each minutes
                [cur_region,~] = Integration.GenerateCC(sub_ppA,sub_BW_ppA);
                cur_CCN = cur_region.CC.NumObjects;
                cur_CC_freq = cur_CCN *(600./frameN); %In case there aren't 600 frames in this sub-movie
                CC_freq(i,1) = cur_CC_freq;
            end
            avg_minute_freq = mean(CC_freq);
            std_minute_freq = std(CC_freq);
            minute_stat = [avg_minute_freq,std_minute_freq];
            checkname = ['CC_' filename(1:length(filename)-4) '_1minFreq.mat'];
            save(fullfile(outputFolder,checkname),'CC_freq','minute_stat');
        end
        

        function renewCC(ppA_roi,outputFolder,filename)
        
        %   Renew connected components in case the standards to define what is
        %   a qualified CC is changed.
        %   
        %   Inputs:
        %   ppA_roi     pre-processed matrix after being chopped to roi
        %   outputFolder     folder that users define to save the oupputs
        %   filename    filename from which current matrix is read in
        %
        %   Outputs:
        %   .mat files that store regionprops, CCs, and BW_ppA matrix after
        %   filtering.
        

                %Black-white thresholding of pre-processed A
                [BW_ppA,~] = Integration.bwThresholding_10prctPixels(ppA_roi); %ppA is short for pre-processed A
                clear Ga_TH_A;
                
                %Compute connected components within each minutes of the movie
                Integration.minuteFreqCC(BW_ppA,ppA_roi,outputFolder,filename) 

                %Generate connected component
                [region,BW_ppA] = Integration.GenerateCC(ppA_roi,BW_ppA);
                checkname = ['CC_' filename(1:length(filename)-4) '_region.mat'];
                save(fullfile(outputFolder,checkname),'region');
                clear TH_A region

                %Save binary movie
                checkname = ['Binary_' filename(1:length(filename)-4) '.mat'];
                save(fullfile(outputFolder,checkname),'BW_ppA','-v7.3');
                clear BW_ppA
        end
        
        
        
        function [curLoad,outputFolder,filename] = readInSingleMatrix(tag,specificF)
        %Read in variables from a .mat file and save them as a struct named
        %curLoad. Read in *_filter.mat files in default.
        %
        %Inputs:
        %   tag          tag specified what kind of .mat files to read
        %   specificF    number specify which .mat file to read
        %
        %Outputs:
        %   curLoad      a struct to store variables read in from .mat
        %   outputFolder     detected outputFolder name
        %   filename     detected filename
        
            disp('Make sure the tag variable can identify .mat files to be read in')
            if ~exist('tag','var')
                tag = 'filtered';
            end

            if ~exist('specificF','var')
                %Did not specify which file to read
               warning('Please specify which file to read!')
            end

            f = specificF;
            cur_Names = Names(f,0);
            filename = cur_Names.filename;
            currentFolder = pwd;
            outputFolder = fullfile(currentFolder,cur_Names.outputFolder);
            checkname = [filename(1:length(filename)-4) '_' tag '.mat'];               
            if exist(fullfile(outputFolder,checkname),'file')
                %Check whether pre-processing has been done before
                disp([tag 'matrix detected, loading .mat file...'])
                curLoad = load(fullfile(outputFolder,checkname));
                disp('')
            else
                disp('')
                disp([tag ' No matrix detected!!!'])
                disp('Try loading matrix from pwd')
                outputFolder = fullfile(currentFolder);
                if exist(fullfile(outputFolder,checkname),'file')
                    %Check whether pre-processing has been done before
                    disp([tag 'matrix detected, loading .mat file...'])
                    curLoad = load(fullfile(outputFolder,checkname));
                    disp('')
                else
                    disp([tag ' No matrix detected!!!'])
                    warning('Inquired matrix does not exist...')
                end
                disp('')
            end
        end
        
    end
end
