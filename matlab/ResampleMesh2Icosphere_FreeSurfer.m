function ResampleMesh2Icosphere_FreeSurfer(data_dir, tmp_dir, subject, output_dir, hemisphere, surface, order, scan)
% RESAMPLEMESH2ICOSPHERE_FREESURFER  Put a mid-surface into icosphere correspondence.
%
%   The x, y and z coordinates of the mid-surface are treated as three scalar
%   overlays, resampled through the subject's spherical registration onto a
%   standard icosphere, and reassembled into a mesh. Every subject then has the
%   same vertex count and the same vertex ordering, so vertex i means the same
%   anatomical location across the cohort.
%
%   Writes <output_dir>/<hemi>_<surface>_ico_<order>.obj
%
%   Requires on the MATLAB path (via $WMBA_MATLAB_MODULES):
%       read_surf, write_curv, read_curv, freesurfer_read_tri,
%       writeObjMesh2, MeshNormal
%   Requires in the environment:
%       WMBA_ICO_DIR   directory holding ic<order>.tri
%       WMBA_SURF2ICO  path to mri_surf2ico.sh
%
%   Original: ResampleMesh2Icosphere_FreeSurfer.m

    ico_dir  = getenv('WMBA_ICO_DIR');
    surf2ico = getenv('WMBA_SURF2ICO');
    if isempty(ico_dir) || isempty(surf2ico)
        error('ResampleMesh2Icosphere:notConfigured', ...
              'set WMBA_ICO_DIR and WMBA_SURF2ICO in config/config.sh');
    end

    subj_tmp = fullfile(tmp_dir, subject);
    surf_tmp = fullfile(subj_tmp, 'surf');
    if ~exist(surf_tmp, 'dir')
        mkdir(surf_tmp);
    end
    cleanup = onCleanup(@() rmdir(subj_tmp, 's'));

    src_surf = fullfile(data_dir, subject, scan, 'surf');
    copyfile(fullfile(src_surf, [hemisphere '.' surface]), ...
             fullfile(surf_tmp,  [hemisphere '.' surface]));
    % mri_surf2ico.sh expects the registration to be called <hemi>.sphere.reg
    copyfile(fullfile(src_surf, [hemisphere '.sphere.reg1']), ...
             fullfile(surf_tmp,  [hemisphere '.sphere.reg']));

    % --- coordinates as three scalar overlays ------------------------------
    [coords, faces] = read_surf(fullfile(surf_tmp, [hemisphere '.' surface]));
    face_num = size(faces, 1);
    axes_names = {'x', 'y', 'z'};
    for a = 1:3
        write_curv(fullfile(surf_tmp, [hemisphere '.' axes_names{a} '.curv']), ...
                   coords(:, a), face_num);
    end

    % --- resample each overlay onto the icosphere --------------------------
    for a = 1:3
        out = fullfile(subj_tmp, [hemisphere '.' surface '_ico' order '_' axes_names{a}]);
        cmd = sprintf('%s %s %s %s %s %s.curv %s', ...
                      surf2ico, tmp_dir, subject, order, hemisphere, axes_names{a}, out);
        [status, msg] = system(cmd);
        if status ~= 0
            error('ResampleMesh2Icosphere:surf2icoFailed', ...
                  'mri_surf2ico.sh failed (%s axis): %s', axes_names{a}, msg);
        end
    end

    % --- reassemble --------------------------------------------------------
    x = read_curv(fullfile(subj_tmp, [hemisphere '.' surface '_ico' order '_x']));
    y = read_curv(fullfile(subj_tmp, [hemisphere '.' surface '_ico' order '_y']));
    z = read_curv(fullfile(subj_tmp, [hemisphere '.' surface '_ico' order '_z']));
    [~, faces] = freesurfer_read_tri(fullfile(ico_dir, ['ic' order '.tri']));
    verts = [x y z];

    ico_obj_file = fullfile(output_dir, [hemisphere '_' surface '_ico_' order '.obj']);
    writeObjMesh2(verts, MeshNormal(verts, faces), faces, ico_obj_file);
end
