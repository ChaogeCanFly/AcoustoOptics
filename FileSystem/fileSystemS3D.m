classdef fileSystemS3D < fileSystem
    
    properties
        
    end
    
    methods (Static)
        function uVars = uVarsCreate()
            uVars = fileSystem.uVarsCreate();
        end
    end
    
    methods
        function this = fileSystemS3D(hOwner, subObjHandle)
            this@fileSystem(hOwner, subObjHandle)
            this.uVars   = fileSystemS3D.uVarsCreate();
            this.fsName  = "S3D";
            this.objName = "3DScan";
            this.resDirName = "2DResults";
        end
        
        function setUserVars(this, uVars)
           uVars.stackAllSubObjRes = false;
           setUserVars@fileSystem(this, uVars);
        end
        
        function configFileSystem(this, secondAxis)
           configFileSystem@fileSystem(this);
           this.scanIdentifierSuffixModel =  sprintf("%s-%s", secondAxis, "%.2f");
           this.hSubFS.setExtVars(this.projPath, "");
        end
        
        function saveVarsToDisk(this)
            saveVarsToDisk@fileSystem(this);
%             this.saveSubFSVarsToDisk();
        end
    end
end

