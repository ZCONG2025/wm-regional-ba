function obj_convert(scan_dir, subject, level, hemi)
% OBJ_CONVERT  Extract vertex coordinates from an icosphere-resampled surface.
%
%   obj_convert(scan_dir, subject, level, hemi)
%
%   Reads  <scan_dir>/midsurf/lvl<level>/<hemi>_lvl<level>_ico_<order>.obj
%   Writes <scan_dir>/midsurf/lvl<level>/<hemi>_coord.mat  (variable: coord, Nx3)
%
%   wmba.sampling reads the .mat. Requires SurfStat on the MATLAB path
%   (set WMBA_MATLAB_MODULES in config/config.sh).
%
%   Original: obj_convert.m

    if isnumeric(level)
        level = num2str(level);
    end

    order = getenv('WMBA_ICO_ORDER');
    if isempty(order)
        order = '6';
    end

    mid_dir  = fullfile(scan_dir, 'midsurf', ['lvl' level]);
    obj_path = fullfile(mid_dir, [hemi '_lvl' level '_ico_' order '.obj']);

    if ~isfile(obj_path)
        error('obj_convert:missingInput', ...
              'no icosphere surface for %s: %s', subject, obj_path);
    end

    surf  = SurfStatReadSurf1(obj_path);
    coord = surf.coord';                                     %#ok<NASGU>

    save(fullfile(mid_dir, [hemi '_coord.mat']), 'coord');
end
