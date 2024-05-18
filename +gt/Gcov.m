classdef Gcov < handle
    % Gcov: GNSS position/velocity covariance class
    %
    % Gcov Declaration:
    % obj = Gcov(cov, 'type', [orgpos], ['orgtype'])
    %   cov      : Nx6, vector of elements of covariance
    %                  [c_xx, c_yy, c_zz, c_xy, c_yz, c_zx] or
    %                  [c_ee,c_nn,c_uu,c_en,c_nu,c_ue] or
    %              3x3xN, covariance matrix
    %   type     : 1x3, Coordinate type: 'xyz' or 'enu'
    %   [orgpos] : 1x3, Coordinate origin [option] 1x3 or 3x1 position vector
    %   [orgtype]: 1x1, Position type [option]: 'llh' or 'xyz'
    % 
    % obj = Gcov(gpos)
    %   gpos   : 1x1, gt.Gpos
    % 
    % Gcov Properties:
    %   n       : 1x1, Number of epochs
    %   xyz     : (obj.n)x6, vector of elements of covariance in ECEF
    %   enu     : (obj.n)x6, vector of elements of covariance in ENU
    %   orgllh  : 1x3, Coordinate origin (deg, deg, m)
    %   orgxyz  : 1x3, Coordinate origin in ECEF (m, m, m)
    %
    % Methods:
    %   setGpos(gpos):
    %   setCovVec(cov, type):
    %   setCov(cov, type):
    %   setOrg(pos, type):
    %   append(gcov):
    %   gcov = select(idx):
    %   cov = covXYZ([idx]):
    %   cov = covENU([idx]):
    %   var = varXYZ([idx]):
    %   var = varENU([idx]):
    %   sd = sdXYZ([idx]):
    %   sd = sdENU([idx]):
    %   plot([idx]):
    %   plotXYZ([idx]):
    %   help()
    %
    % Author: Taro Suzuki

    properties
        n, xyz, enu, orgllh, orgxyz;
    end

    methods
        %% constractor
        function obj = Gcov(varargin)
            if nargin == 1
                obj.setGpos(varargin{1});
            elseif nargin>=2 % cov, covtype, org, orgtype
                if size(varargin{1}, 2) == 6
                    obj.setCovVec(varargin{1}, varargin{2});
                elseif size(varargin{1}, 1) == 3 && size(varargin{1}, 2) == 3
                    obj.setCov(varargin{1}, varargin{2});
                else
                    error('Wrong input arguments');
                end
            end
            if nargin==4; obj.setOrg(org, orgtype); end
        end

        %% set gt.Gpos
        function setGpos(obj, gpos)
            arguments
                obj gt.Gcov
                gpos gt.Gpos
            end            
            obj.n = 1;
            if ~isempty(gpos.enu)
                obj.enu = [var(gpos.enu, 'omitnan') 0 0 0];
            else
                obj.xyz = [var(gpos.xyz, 'omitnan') 0 0 0];
            end
            if ~isempty(gpos.orgllh)
                obj.setOrg(gpos.orgllh, 'llh');
            end
        end

        %% set covariance vector
        function setCovVec(obj, cov, covtype)
            arguments
                obj gt.Gcov
                cov (:,6) double
                covtype (1,:) char {mustBeMember(covtype,{'xyz','enu'})}
            end
            obj.n = size(cov,1);
            switch covtype
                case 'xyz'
                    obj.xyz = cov;
                    if ~isempty(obj.orgllh); obj.enu = rtklib.covenusol(obj.xyz, obj.orgllh); end
                case 'enu'
                    obj.enu = cov;
                    if ~isempty(obj.orgllh); obj.xyz = rtklib.covecefsol(obj.enu, obj.orgllh); end
            end
        end

        %% set covariance matrix
        function setCov(obj, cov, covtype)
            arguments
                obj gt.Gcov
                cov (3,3,:) double
                covtype (1,:) char {mustBeMember(covtype,{'xyz','enu'})}
            end
            obj.n = size(cov,3);
            switch covtype
                case 'xyz'
                    obj.xyz = obj.mat2vec(cov);
                    if ~isempty(obj.orgllh); obj.enu = rtklib.covenusol(obj.xyz, obj.orgllh); end
                case 'enu'
                    obj.enu = obj.mat2vec(cov);
                    if ~isempty(obj.orgllh); obj.xyz = rtklib.covecefsol(obj.enu, obj.orgllh); end
            end
        end

        %% set coordinate orgin
        function setOrg(obj, org, orgtype)
            arguments
                obj gt.Gcov
                org (1,3) double
                orgtype (1,:) char {mustBeMember(orgtype,{'llh','xyz'})}
            end
            switch orgtype
                case 'llh'
                    obj.orgllh = org;
                    obj.orgxyz = rtklib.llh2xyz(org);
                case 'xyz'
                    obj.orgxyz = org;
                    obj.orgllh = rtklib.xyz2llh(org);
            end
            if ~isempty(obj.xyz)
                obj.enu = rtklib.covenusol(obj.xyz, obj.orgllh);
            elseif ~isempty(obj.enu)
                obj.xyz = rtklib.covecefsol(obj.enu, obj.orgllh);
            end
        end

        %% append
        function append(obj, gcov)
            arguments
                obj gt.Gcov
                gcov gt.Gcov
            end
            if ~isempty(obj.xyz)
                obj.setCovVec([obj.xyz; gcov.xyz], 'xyz');
            else
                obj.setCovVec([obj.enu; gcov.enu], 'enu');
            end
        end

        %% copy
        function gcov = copy(obj)
            arguments
                obj gt.Gcov
            end
            gcov = obj.select(1:obj.n);
        end

        %% select from index
        function gcov = select(obj, idx)
            arguments
                obj gt.Gcov
                idx {mustBeInteger, mustBeVector}
            end
            if ~any(idx)
                error('Selected index is empty');
            end
            if ~isempty(obj.xyz)
                gcov = gt.Gcov(obj.xyz(idx,:), 'xyz');
            else
                gcov = gt.Gcov(obj.enu(idx,:), 'enu');
            end
            if ~isempty(obj.orgllh); gcov.setOrg(obj.orgllh, 'llh'); end
        end

        %% access
        % 3X3 covariance matrix
        function cov = covXYZ(obj, idx)
            arguments
                obj gt.Gcov
                idx {mustBeInteger, mustBeVector} = 1:obj.n
            end
            if isempty(obj.xyz)
                error('xyz must be set to a value');
            end
            cov = obj.vec2matrix(obj.xyz(idx,:));
        end
        function cov = covENU(obj, idx)
            arguments
                obj gt.Gcov
                idx {mustBeInteger, mustBeVector} = 1:obj.n
            end
            if isempty(obj.enu)
                error('enu must be set to a value');
            end
            cov = obj.vec2matrix(obj.enu(idx,:));
        end
        function var = varXYZ(obj, idx)
            arguments
                obj gt.Gcov
                idx {mustBeInteger, mustBeVector} = 1:obj.n
            end
            if isempty(obj.xyz)
                error('xyz must be set to a value');
            end
            var = obj.xyz(idx,1:3);
        end
        function var = varENU(obj, idx)
            arguments
                obj gt.Gcov
                idx {mustBeInteger, mustBeVector} = 1:obj.n
            end
            if isempty(obj.enu)
                error('enu must be set to a value');
            end
            var = obj.enu(idx,1:3);
        end
        function sd = sdXYZ(obj, idx)
            arguments
                obj gt.Gcov
                idx {mustBeInteger, mustBeVector} = 1:obj.n
            end
            if isempty(obj.xyz)
                error('xyz must be set to a value');
            end
            sd = sqrt(obj.xyz(idx,1:3));
        end
        function sd = sdENU(obj, idx)
            arguments
                obj gt.Gcov
                idx {mustBeInteger, mustBeVector} = 1:obj.n
            end
            if isempty(obj.enu)
                error('enu must be set to a value');
            end
            sd = sqrt(obj.enu(idx,1:3));
        end

        %% plot
        function plot(obj, idx)
            arguments
                obj gt.Gcov
                idx {mustBeInteger, mustBeVector} = 1:obj.n
            end
            if isempty(obj.enu)
                error('enu must be set to a value');
            end
            sdenu = obj.sdENU(idx);
            figure;
            plot(sdenu(:, 1), '.-');
            grid on; hold on;
            plot(sdenu(:, 2), '.-');
            plot(sdenu(:, 3), '.-');
            ylabel('SD (m)');
            legend('SD East', 'SD North', 'SD up')
            drawnow
        end
        function plotXYZ(obj, idx)
            arguments
                obj gt.Gcov
                idx {mustBeInteger, mustBeVector} = 1:obj.n
            end
            if isempty(obj.xyz)
                error('xyz must be set to a value');
            end
            sdxyz = obj.sdXYZ(idx);
            figure;
            plot(sdxyz(:, 1), '.-');
            grid on; hold on;
            plot(sdxyz(:, 2), '.-');
            plot(sdxyz(:, 3), '.-');
            ylabel('SD (m)');
            legend('SD ECEF-X', 'SD ECEF-Y', 'SD ECEF-Z')
            drawnow
        end
        
        %% help
        function help(~)
            doc gt.Gcov
        end
    end

    %% private functions
    methods (Access = private)
        % convert
        function mat = vec2matrix(~, vec)
            arguments
                ~
                vec (:,6) double
            end
            r3 = @(x) reshape(x,1,1,[]);
            mat = [r3(vec(:,1)), r3(vec(:,4)), r3(vec(:,6));
                r3(vec(:,4)), r3(vec(:,2)), r3(vec(:,5));
                r3(vec(:,6)), r3(vec(:,5)), r3(vec(:,3))];
        end
        function vec = mat2vec(~,mat)
            arguments
                ~
                mat (3,3,:) double
            end
            r1 = @(x) reshape(x,[],1);
            vec = [r1(mat(1,1,:)), r1(mat(2,2,:)), r1(mat(3,3,:)),...
                r1(mat(1,2,:)), r1(mat(2,3,:)), r1(mat(3,1,:))];
        end
    end
end