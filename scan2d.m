classdef scan2d < scanObj
    %SCAN2D Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
    end
    
    methods (Static)
        
        
        function uVars = uVarsCreate()
            uVars.acoustoOptics = acoustoOptics.uVarsCreate();
           
            uVars.fileSystem.scanName        = [];
            uVars.fileSystem.resDirPath      = [];
            uVars.fileSystem.saveFullData    = false;
            uVars.fileSystem.saveReducedData = false;
            uVars.fileSystem.saveFigs        = false;
           
            uVars.stages.startX  = 0;
            uVars.stages.startY  = 0;
            uVars.stages.endX    = 0;
            uVars.stages.endY    = 0;
            uVars.stages.strideX = 0;
            uVars.stages.strideY = 0;
            uVars.stages.firstAxis = 'Y';
            
            uVars.scan.useQuant = false;
            uVars.scan.speckleTime = 0;
            
            uVars.gReq = scan2d.createGraphicRequest();
        end
        
        function gReq = createGraphicRequest()
            gReq = scan2dGraphics.createGraphicsRunVars();
        end
    end
    
    methods
        function this = scan2d(acoustoOpticHandle, stagesHandle, owner)
            this@scanObj(acoustoOpticHandle, stagesHandle, owner);
            
            this.strings.scan = "Done Scan for (R,X,Y,Q) = (%d, %.2f, %.2f, %d)";
            this.strings.timeTable = "R%dX%.2fY%.2fQ%d";
            
            this.graphics.graphicsNames = scan2dGraphics.getGraphicsNames();
            this.graphics.obj           = scan2dGraphics(); 
            this.graphics.gReq          = scan2dGraphics.createGraphicsRunVars();
            this.graphics.ownerGraphUpdate = true;
        end
        
        function setScanUserVars(this, uVars)
            this.scan.timeToSample = uVars.timeToSample;
            this.scan.quantTime    = uVars.quantTime;
            this.scan.useQuant     = uVars.useQuant;
            this.scan.repeats      = uVars.repeats;
            
            if this.scan.useQuant
                this.scan.numOfQuant   = ceil(this.scan.timeToSample / uVars.quantTime);
                this.scan.timeToSample = this.scan.quantTime;
            else 
                this.scan.numOfQuant   = 1;
                this.scan.timeToSample = this.scan.timeToSample;
            end
        end
        
        function initResultsArrays(this)
            this.results.phiCh     = zeros(this.stages.vars.xIdxLen, this.stages.vars.yIdxLen, this.scan.zIdxLen, this.scan.repeats, this.scan.numOfQuant, this.scan.channels);
            this.results.phiQuant  = zeros(this.stages.vars.xIdxLen, this.stages.vars.yIdxLen, this.scan.zIdxLen, this.scan.repeats, this.scan.numOfQuant);
            this.results.phiRepStd = zeros(this.stages.vars.xIdxLen, this.stages.vars.yIdxLen, this.scan.zIdxLen, this.scan.repeats);
            this.results.phiRep    = zeros(this.stages.vars.xIdxLen, this.stages.vars.yIdxLen, this.scan.zIdxLen, this.scan.repeats);
            this.results.phi       = zeros(this.stages.vars.xIdxLen, this.stages.vars.yIdxLen, this.scan.zIdxLen);
            this.results.phiStd    = zeros(this.stages.vars.xIdxLen, this.stages.vars.yIdxLen, this.scan.zIdxLen);
            
            this.curScan = zeros(1,4);
        end
            
        function initTimeTable(this)
            this.timeTable.scan = struct();
        end
        
        function startScan(this,uVars)
            this.setUserVars(uVars);
            this.initResultsArrays();
            this.setGraphicsDynamicVars();
            this.initTimeTable();
            
            if this.owned
                this.owner.updateS2dGeneralData(...
                    this.acoustoOptics.vars.algoVars.len.zVecUSRes,...
                    this.stages.vars.xVec,...
                    this.stages.vars.yVec,...
                    this.scan.repeats,...
                    this.scan.numOfQuant);
            end
            
            this.stages.obj.moveStageAbs([this.stages.vars.firstVec(1), this.stages.vars.secondVec(1)]);
            for r = 1:this.scan.repeats
                this.curScan(1) = r;
                for i=1:this.stages.vars.secondIdxLen
                    
                    if strcmp(this.stages.vars.firstAxis, 'Y') 
                        this.graphics.obj.updateCurScan([r,i,1,0])
                    elseif strcmp(this.stages.vars.firstAxis, 'X')
                        this.graphics.obj.updateCurScan([r,1,i,0])
                    end

                    if this.owned
                        this.owner.updatePhi(this.results.phi, this.results.phiStd);
                        notify(this.owner, 'updatePhiEvent');
%                         this.graphics.obj.dispCurMainAxisRep(this.results.phi, this.results.phiStd)
%                         this.graphics.obj.dispCurMainPlainRep(this.results.phi)
                    else
                        if this.graphics.gReq.validStruct.curMainAxis
                            this.graphics.obj.dispCurMainAxisRep(this.results.phi, this.results.phiStd)
                        end
                        if this.graphics.gReq.validStruct.curMainPlainRep
                            this.graphics.obj.dispCurMainPlainRep(this.results.phi)
                        end
                    end
                    
                    for j=1:this.stages.vars.firstIdxLen
                        if strcmp(this.stages.vars.firstAxis, 'Y') 
                            this.curScan(2:3) = [this.stages.vars.secondVec(i), this.stages.vars.firstVec(j)];
                        elseif strcmp(this.stages.vars.firstAxis, 'X')
                            this.curScan(2:3) = [this.stages.vars.firstVec(j),  this.stages.vars.secondVec(i)];
                        end
                        this.stages.obj.moveStageAbs(this.stagesVec( this.stages.vars.firstVec(j), this.stages.vars.secondVec(i)))

                        this.printStr(sprintf("Scaninng on Position: (%.2f, %.2f)", this.stages.vars.firstVec(j), this.stages.vars.secondVec(i)), true);
                        this.startScanTime('singlePos');

                        for q=1:this.scan.numOfQuant
                            this.curScan(4) = q;
                            this.printStr(sprintf("Quant number: %d", q), true);
                            this.startScanTime('singleQuant');

                            this.startScanTime('netAcoustoOptics');
                            res = this.acoustoOptics.obj.measureAndAnlayse();
                            this.stopScanTime('netAcoustoOptics');

                            this.startScanTime('copyTime');
                            % keep the data in the same arrays axes no matter what is the scan primary scan axis
                            if strcmp(this.stages.vars.firstAxis, 'Y') 
                                this.results.phiCh(i,j,:,r,q,:)  = permute(gather(res.phiCh), [3,2,4,5,1]);
                                this.results.phiQuant(i,j,:,r,q) = gather(res.phi);
                            elseif strcmp(this.stages.vars.firstAxis, 'X')
                                this.results.phiCh(j,i,:,r,q,:)  = permute(gather(res.phiCh), [2,3,4,5,1]);
                                this.results.phiQuant(j,i,:,r,q) = gather(res.phi);
                            end
                            this.stopScanTime('copyTime');

%                             if (this.scan.useQuant)
%                                 this.shiftSpeckle();
%                             end

                            this.stopScanTime('singleQuant');
                            this.printStr(sprintf(this.strings.scan, this.curScan), true);
                            
                            if strcmp(this.stages.vars.firstAxis, 'Y') 
                                this.graphics.obj.updateCurScan([r,i,j,q])
                            elseif strcmp(this.stages.vars.firstAxis, 'X')
                                this.graphics.obj.updateCurScan([r,j,i,q])
                            end
                            
                        end
                        this.curScan(4) = 0; % for timetable to succeed

                        this.startScanTime('quantMean');
                        if strcmp(this.stages.vars.firstAxis, 'Y')
                            this.results.phiRep(i,j,:,r) = mean(this.results.phiQuant(i,j,:,r,:), 5);
                            this.results.phiRepStd(i,j,:,r) = std(this.results.phiQuant(i,j,:,r,:), 0, 5);
                        elseif strcmp(this.stages.vars.firstAxis, 'X')
                            this.results.phiRep(j,i,:,r) = mean(this.results.phiQuant(j,i,:,r,:), 5);
                            this.results.phiRepStd(j,i,:,r) = std(this.results.phiQuant(j,i,:,r,:), 0, 5);
                        end
                        this.stopScanTime('quantMean');
                        
                        if this.owned
                            this.owner.updatePhiRep(this.results.phiRep, this.results.phiRepStd, this.curScan);
                            notify(this.owner, 'updatePhiRepEvent');
                            notify(this.owner, 'timeTable');
%                             this.graphics.obj.dispCurMainAxis(this.results.phiRep, this.results.phiRepStd)
%                             this.graphics.obj.dispCurMainPlain(this.results.phiRep)
                        else
                            if this.graphics.gReq.validStruct.curMainAxis
                                this.graphics.obj.dispCurMainAxis(this.results.phiRep, this.results.phiRepStd)
                            end
                            if this.graphics.gReq.validStruct.curMainPlain
                                this.graphics.obj.dispCurMainPlain(this.results.phiRep)
                            end
                        end
                        
                        this.stopScanTime('singlePos');
                    end
                end
                this.curScan(2:3) = 0;
                
                %it doesn't have to be here but it's here so graphics could
                %create a real time mean illustration 
                if strcmp(this.stages.vars.firstAxis, 'Y')
                            this.results.phi    = mean(this.results.phiRep(:,:,:,1:r), 4);
                            this.results.phiStd = std(this.results.phiRep(:,:,:,1:r), 0, 4);
                elseif strcmp(this.stages.vars.firstAxis, 'X')
                            this.results.phi    = mean(this.results.phiRep(:,:,:,1:r), 4);
                            this.results.phiStd = std(this.results.phiRep(:,:,:,1:r), 0, 4);
                end
                
                if this.owned
                    this.owner.updatePhi(this.results.phi, this.results.phiStd);
                    notify(this.owner, 'updatePhiEvent');
%                     this.graphics.obj.dispCurMainAxisRep(this.results.phi, this.results.phiStd)
                elseif this.graphics.gReq.validStruct.curMainAxis
                    this.graphics.obj.dispCurMainAxisRep(this.results.phi, this.results.phiStd)
                end
            end
            
            if this.owned
                this.owner.updatePhi(this.results.phi, this.results.phiStd);
                notify(this.owner, 'updatePhiEvent');
%                 this.graphics.obj.dispCurMainAxisRep(this.results.phi, this.results.phiStd)
            elseif this.graphics.gReq.validStruct.curMainAxis
                this.graphics.obj.dispCurMainAxisRep(this.results.phi, this.results.phiStd)
            end
            
            this.saveResults();
        end
        
        % Stages Variables Code
        
        function calcStagesVars(this)
            this.stages.vars.xVec    = this.stages.vars.startX:this.stages.vars.strideX:this.stages.vars.endX;
            this.stages.vars.yVec    = this.stages.vars.startY:this.stages.vars.strideY:this.stages.vars.endY;
            
            this.stages.vars.xLen    = abs(this.stages.vars.startX - this.stages.vars.endX);
            this.stages.vars.yLen    = abs(this.stages.vars.startY - this.stages.vars.endY);
            this.stages.vars.xIdxLen = length(this.stages.vars.xVec);
            this.stages.vars.yIdxLen = length(this.stages.vars.yVec);
            this.stages.vars.xIdx    = 1:1:this.stages.vars.xIdxLen;        
            this.stages.vars.yIdx    = 1:1:this.stages.vars.yIdxLen;
            
            switch this.stages.vars.firstAxis
                case 'Y'
                    this.stages.vars.startFirst   = this.stages.vars.startY;
                    this.stages.vars.strideFirst  = this.stages.vars.strideY;
                    this.stages.vars.endFirst     = this.stages.vars.endY;
                    
                    this.stages.vars.startSecond  = this.stages.vars.startX;
                    this.stages.vars.strideSecond = this.stages.vars.strideX;
                    this.stages.vars.endSecond    = this.stages.vars.endX;
                    
                    this.stages.vars.firstVec     = this.stages.vars.yVec;
                    this.stages.vars.secondVec    = this.stages.vars.xVec;
                    
                    this.stages.vars.firstLen     = this.stages.vars.yLen;
                    this.stages.vars.secondLen    = this.stages.vars.xLen;
                    this.stages.vars.firstIdxLen  = this.stages.vars.yIdxLen;
                    this.stages.vars.secondIdxLen = this.stages.vars.xIdxLen;
                    this.stages.vars.firstIdx     = this.stages.vars.yIdx;
                    this.stages.vars.secondIdx    = this.stages.vars.xIdx;
                    
                case 'X'
                    this.stages.vars.startFirst   = this.stages.vars.startX;
                    this.stages.vars.strideFirst  = this.stages.vars.strideX;
                    this.stages.vars.endFirst     = this.stages.vars.endX;
                    
                    this.stages.vars.startSecond  = this.stages.vars.startY;
                    this.stages.vars.strideSecond = this.stages.vars.strideY;
                    this.stages.vars.endSecond    = this.stages.vars.endY;
                    
                    this.stages.vars.firstVec     = this.stages.vars.xVec;
                    this.stages.vars.secondVec    = this.stages.vars.yVec;
                    
                    this.stages.vars.firstLen     = this.stages.vars.xLen;
                    this.stages.vars.secondLen    = this.stages.vars.yLen;
                    this.stages.vars.firstIdxLen  = this.stages.vars.xIdxLen;
                    this.stages.vars.secondIdxLen = this.stages.vars.yIdxLen;
                    this.stages.vars.firstIdx     = this.stages.vars.xIdx;
                    this.stages.vars.secondIdx    = this.stages.vars.yIdx;
            end
        end
        
        function vec = stagesVec(this, first, second)
           switch this.stages.vars.firstAxis
               case 'Y'
                   vec = [second, first];
               case 'X'
                   vec = [first, second];
           end
        end
        
        function setStagesUserVars(this, uVars)
            this.stages.vars.startX  = uVars.startX;
            this.stages.vars.strideX = uVars.strideX;
            this.stages.vars.endX    = uVars.endX;
            
            this.stages.vars.startY  = uVars.startY;
            this.stages.vars.strideY = uVars.strideY;
            this.stages.vars.endY    = uVars.endY;
            
            this.stages.vars.firstAxis = uVars.firstAxis;
            
            this.calcStagesVars()
        end
        
        % Graphics Code
        function setGraphicsDynamicVars(this)
            if this.scan.useQuant
                this.graphics.obj.setType(this.graphics.graphicsNames{1}, 'errorbar')
            else
                this.graphics.obj.setType(this.graphics.graphicsNames{1}, 'stem')
            end
            
            if this.scan.repeats > 1
                this.graphics.obj.setType(this.graphics.graphicsNames{2}, 'errorbar')
            else
                this.graphics.obj.setType(this.graphics.graphicsNames{2}, 'stem')
            end
            zAxis = this.acoustoOptics.vars.algoVars.len.zVecUSRes;
            this.graphics.obj.setAxesVec(this.stages.vars.xVec, this.stages.vars.yVec, zAxis)
            this.graphics.obj.setMainAx(this.stages.vars.firstAxis)
            names = this.graphics.graphicsNames;
            for i = 1:length(names)
                this.graphics.obj.setUpdate(names{i}, true);
            end
            this.graphics.obj.updateGraphicsConstruction()
        end

        function gH = getGraphicsHandle(this)
            gH = this.graphics.obj;
        end
    end
end

