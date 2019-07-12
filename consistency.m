classdef Consistency < scanObj
    %CONSISTENCYOBJ Summary of this class goes here
    %   Detailed explanation goes here
    
    properties

    end
    
    methods (Static)
       
        function uVars = uVarsCreate()
            uVars.acoustoOptice = acoustoOptics.uVarsCreate();
           
            uVars.stages.xPos = [];
            uVars.stages.yPos = [];

            uVars.fileSystem.scanName        = [];
            uVars.fileSystem.resDirPath      = [];
            uVars.fileSystem.saveFullData    = false;
            uVars.fileSystem.saveReducedData = false;
            uVars.fileSystem.saveFigs        = false;
            uVars.fileSystem.saveResults     = false;
            
            uVars.scan.startTime   = [];
            uVars.scan.stride      = [];
            uVars.scan.endTime     = [];
            uVars.scan.useQuant    = false;
            uVars.scan.quantTime   = [];
            uVars.scan.numOfSets   = [];
            
            uVars.gReq = Consistency.createGraphicRequest();
            
        end
        
        function gReq = createGraphicRequest()
            gReq = consGraphics.createGraphicsRunVars();
        end
        
    end
    
    methods
        
        function this = Consistency(acoustoOpticHandle, stagesHandle, owner)
            %Pass arguments to father constructor
            this@scanObj(acoustoOpticHandle, stagesHandle, owner); 
            
            %Set Strings:
            this.strings.scan = "Done Scan for (F,S,Q) = (%8.3f, %d, %d)\n";
            this.strings.timeTable = "F%dS%dQ%d";

            %Init Graphics
            this.graphics.graphicsNames = consGraphics.getGraphicsNames();
            this.graphics.obj = consGraphics(); 
            this.graphics.gReq = consGraphics.createGraphicsRunVars();
            this.graphics.ownerGraphUpdate = true;
            
            %Init Control Vars
            this.curScan = ones(1,3);
        end

        function setScanUserVars(this, uVars)
            this.scan.timeFrames  = uVars.startTime : uVars.stride : uVars.endTime;
            this.scan.numOfFrames = length(this.scan.timeFrames);
            this.scan.quantTime   = uVars.quantTime;
            this.scan.useQuant    = uVars.useQuant;
            this.scan.numOfSets   = uVars.numOfSets;
            
            if this.scan.useQuant
                this.scan.numOfQuant   = ceil(this.scan.timeFrames / this.scan.quantTime);
                this.scan.timeToSample = ones(1, this.scan.numOfFrames) * this.scan.quantTime; 
            else 
                this.scan.numOfQuant   = ones(1, this.scan.numOfFrames);
                this.scan.timeToSample = this.scan.timeFrames;
            end
        end
        
        function setStagesUserVars(this, uVars) 
           this.stages.vars.uVars = uVars;
           this.stages.vars.xPos  = uVars.xPos;
           this.stages.vars.yPos  = uVars.yPos;
        end
  
        function initResultsArrays(this)
            this.results.phiCh       = zeros(this.scan.zIdxLen, this.scan.numOfFrames, this.scan.numOfSets, this.scan.numOfQuant(end), this.scan.channels);
            this.results.phiQuant    = zeros(this.scan.zIdxLen, this.scan.numOfFrames, this.scan.numOfSets, this.scan.numOfQuant(end));
            this.results.phiSets     = zeros(this.scan.zIdxLen, this.scan.numOfFrames, this.scan.numOfSets);
            this.results.phiFrame    = zeros(this.scan.zIdxLen, this.scan.numOfFrames);
            
            this.results.phiSetsStd  = zeros(this.scan.zIdxLen, this.scan.numOfFrames, this.scan.numOfSets);
            this.results.phiFrameStd = zeros(this.scan.zIdxLen, this.scan.numOfFrames);
        end
        
        function startScan(this, uVars)
            this.setUserVars(uVars); % in the consistency space
            this.resetTimeTable();
            this.initResultsArrays();
            this.setGraphicsDynamicVars();
            
            if this.owned
%                 this.owner.updateConsGeneralData(this.scan, this.acoustoOptics.vars.len.zVecUSRes)
                this.owner.initConsData(this.results, this.scan, this.acoustoOptics.vars.algoVars.len.zVecUSRes)
            end
            this.stages.obj.moveStageAbs(...
                                         [this.stages.vars.xPos,...
                                          this.stages.vars.yPos]);
                                      
            this.curScan = zeros(1,3);
            if this.scan.useQuant
                this.acoustoOptics.vars.uVars.timeToSample = this.scan.timeToSample(1);
                setAcoustoOpticsUserVars(this, this.acoustoOptics.vars.uVars);
            end
            
            for i = 1:this.scan.numOfFrames
                this.printStr(sprintf("------------------Starting a New Time Frame----------------------\n"), true);
                
                if ~(this.scan.useQuant)
                    this.acoustoOptics.vars.uVars.timeToSample = this.scan.timeFrames(i);
                    setAcoustoOpticsUserVars(this, this.acoustoOptics.vars.uVars); %set & update            
                end
                
                this.curScan(1) = i;
                for j=1:this.scan.numOfSets
                    this.printStr(sprintf("------------------Starting a New Set----------------------\n"), true);
                    this.curScan(2) =  j;
                    
                    this.graphics.obj.setCurrentFrameAndSet(this.curScan(1), this.curScan(2));
                    
                    for k=1:this.scan.numOfQuant(i)
                        this.curScan(3) = k;
                        this.startScanTime('singleQuant');
                        
                        this.startScanTime('netAcoustoOptics');
                        res = this.acoustoOptics.obj.measureAndAnlayse();
                        this.stopScanTime('netAcoustoOptics');
                        
                        this.startScanTime('copyTime');
                        this.results.phiCh(:,i,j,k,:)  = permute(gather(res.phiCh), [2,3,4,5,1]);
                        this.results.phiQuant(:,i,j,k) = gather(res.phi);
                        this.stopScanTime('copyTime');
                        
%                         if (this.scan.useQuant)
%                             this.shiftSpeckle();
%                         end

                        this.stopScanTime('singleQuant');
                        this.storeAcoustoOpricTimeTable();
                        this.printStr(sprintf(this.strings.scan, this.curScan(1), this.curScan(2), this.curScan(3)), true);
                        
                        if this.owned
                            this.owner.updateConsistencyPhiQuant(this.results.phiQuant, this.curScan);
                            notify(this.owner, 'updateQuant');
                            notify(this.owner, 'timeTable');
                        elseif this.graphics.gReq.validStruct.curSet && this.scan.useQuant
                            this.graphics.obj.dispCurrentSet('curSet', 1:this.scan.numOfQuant, this.results.phiQuant, [])
                        end
                        
                    end
                    
                    this.startScanTime('setMean');
                    this.results.phiSets(:,i,j)    = mean(this.results.phiQuant(:,i,j,1:this.scan.numOfQuant(i)), 4);
                    this.results.phiSetsStd(:,i,j) = std(this.results.phiQuant(:,i,j,1:this.scan.numOfQuant(i)), 0, 4);
                    this.stopScanTime('setMean');
                    
                    % Update Plots
                    
                    if this.owned
                    	this.owner.updateConsistencyPhiSet(this.results.phiSets, this.results.phiSetsStd, this.curScan);
                    	notify(this.owner, 'updateSet');
                    elseif this.graphics.gReq.validStruct.curFrame
                        this.graphics.obj.dispCurrentFrame('curFrame', 1:this.scan.numOfSets, this.results.phiSets, this.results.phiSetsStd)
                    end

                end
                
                this.startScanTime('frameMean');
                this.results.phiFrame(:,i)    = mean(this.results.phiSets(:,i,:), 3);
                this.results.phiFrameStd(:,i) = std(this.results.phiQuant(:,i,:), 0, 3);
                this.stopScanTime('frameMean');
                
                % UpdatePlots parameters
%                 this.setGraphicsDynamicVars();
                
                if this.owned
                    this.owner.updateConsistencyPhiFrame(this.results.phiFrame, this.results.phiFrameStd, this.curScan);
                    notify(this.owner, 'updateFrame');
                elseif  this.graphics.gReq.validStruct.allFrames && this.graphics.ownerGraphUpdate
                    this.graphics.obj.dispTotalFrame('allFrames', this.scan.timeFrames, this.results.phiFrame, this.results.phiFrameStd)
                end
                
                % release buffers before reconfiguring the digitizer
                if ~(this.scan.useQuant)
                     this.acoustoOptics.obj.resetDigitizerMem(); %release Buufers
                end
            end
            this.saveResults();
        end
        
        function setGraphicsDynamicVars(this)
%             curFrame = this.scan.timeFrames(this.curScan(1));
%             curSet = this.curScan(2);
            
            if this.scan.useQuant
                this.graphics.obj.setType(this.graphics.graphicsNames{4}, 'errorbar')
                this.graphics.obj.setType(this.graphics.graphicsNames{2}, 'errorbar')
            else
                this.graphics.obj.setType(this.graphics.graphicsNames{2}, 'stem')
                this.graphics.obj.setType(this.graphics.graphicsNames{4}, 'stem')
            end
            this.graphics.obj.setChAndPos(this.graphics.gReq.ch, this.graphics.gReq.zIdx);
            this.graphics.obj.setTimeFramesAndQuants(this.scan.timeFrames, this.scan.numOfQuant); 
            this.graphics.obj.setCurrentFrameAndSet(1, 1);
%             this.graphics.obj.setTitleVariables(this.graphics.graphicsNames{1}, {[]});
%             this.graphics.obj.setTitleVariables(this.graphics.graphicsNames{2}, {[curFrame]});
%             this.graphics.obj.setTitleVariables(this.graphics.graphicsNames{3}, {[curSet]});
            
            this.graphics.obj.updateGraphicsConstruction()
        end

    end
end

