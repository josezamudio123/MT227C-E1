%ESCENARIOS_E1  Escenarios comunes C1-C4 con el diseño final, en el simulador OFICIAL del kit
%   (saturación, estimador base, cuantización, ruido base, Ts = 2 ms). C5 no aplica a E1.
%   Salidas: resultados/escenarios.mat, trayectorias/C1.csv ... C3b.csv, videos/C1.mp4 y C2.mp4.
%   Semillas: C1-C3b con semilla de ruido 1; C4 con la convención del kit (planta i: 1000 + i,
%   ruido i, i = 1..200).

clear; clc; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
d = diseno_base_qube();
[K, info] = diseno_final();
ctrl = controlador_lineal(K); est = estimador_base(d);
if ~isfolder(fullfile(raiz, 'trayectorias')), mkdir(fullfile(raiz, 'trayectorias')); end
if ~isfolder(fullfile(raiz, 'videos')), mkdir(fullfile(raiz, 'videos')); end
fprintf('Diseño final: %s\nK = %s\n\n', info.nombre, mat2str(K, 6));

esc = struct(); logs = struct();
fprintf('%-4s %-6s %9s %8s %9s %9s %9s %10s %6s\n', 'esc.', 'estado', 'J', 'ts [s]', 'max|u_c|', 'max|u|', 'sat [%]', 'max|theta|', 'éxito');
for nombre = {'C1', 'C2', 'C3', 'C3b'}
    e = escenario_qube(nombre{1});
    L = simular_qube(ctrl, est, e, struct('semilla', 1));
    m = metricas_qube(L);
    esc.(e.nombre) = m; logs.(e.nombre) = L;
    exportar_trayectoria(L, fullfile(raiz, 'trayectorias', [e.nombre '.csv']));
    ts = m.ts; if isempty(ts), ts = NaN; end
    fprintf('%-4s %-6s %9.4f %8.3f %9.2f %9.2f %9.1f %10.3f %6d\n', e.nombre, m.estado, m.J, ts, m.max_uc, ...
            m.max_u, 100*m.frac_sat, m.max_theta, m.exito);
end

fprintf('\nC4: Monte Carlo de 200 plantas (mp, Lp, Rm, kt en +-20 %%)...\n'); tic;
r4 = resumen_c4(ctrl, est, 200);
fprintf('C4: éxito en %d de %d plantas (%.1f %%), %.0f s. Fallidas: %s\n', r4.n_exito, r4.n, 100*r4.tasa_exito, toc, mat2str(r4.fallidos));
fprintf('    J: media %.4f, desv. %.4f, p95 %.4f | max|theta|: media %.3f, p95 %.3f rad\n', ...
        r4.J.media, r4.J.desv, r4.J.p95, r4.max_theta.media, r4.max_theta.p95);
if ~isempty(r4.fallidos)
    fprintf('    Factores [mp Lp Rm kt] de las plantas fallidas:\n'); disp(r4.factores(r4.fallidos, :));
end

save(fullfile(raiz, 'resultados', 'escenarios.mat'), 'esc', 'r4', 'K');
fprintf('Guardado: resultados/escenarios.mat y trayectorias/C1-C3b.csv\n');

% Videos: figura INVISIBLE y de tamaño fijo, para que todos los cuadros midan lo mismo
% (VideoWriter lo exige; con la escala de texto de Windows > 100 %, una figura visible puede
% cambiar de tamaño durante la grabación). No se modifica el kit: solo el tamaño por defecto.
fprintf('\nGenerando videos de C1 y C2 (animar_qube, desde las trayectorias del kit)...\n');
pos_ant = get(groot, 'defaultFigurePosition');
set(groot, 'defaultFigurePosition', [100 100 960 720]);
try
    for nombre = {'C1', 'C2'}
        animar_qube(logs.(nombre{1}), struct('archivo', fullfile(raiz, 'videos', [nombre{1} '.mp4']), ...
                    'tiempo_real', false, 'visible', false));
        close all;
    end
catch err
    set(groot, 'defaultFigurePosition', pos_ant);
    rethrow(err);
end
set(groot, 'defaultFigurePosition', pos_ant);
fprintf('Guardado: videos/C1.mp4 y videos/C2.mp4\n');
