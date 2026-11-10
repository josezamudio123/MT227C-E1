%EJEMPLO_RUN_ALL Ejemplo de uso del kit v1.1 con el diseño base. Punto de partida del run_all del grupo.
%   Genera trayectorias/*.csv, results_ejemplo.json (escenarios) y, si VideoWriter está
%   disponible (MATLAB), los videos C1.mp4 y C2.mp4. Al final abre el visor interactivo.
clear; close all; clc;
p = parametros_qube(); d = diseno_base_qube();
ctrl = controlador_lineal(d.K0);      % reemplazar por el controlador del grupo
est  = estimador_base(d);             % E2 y E3 reemplazan por su estimador
if ~exist('trayectorias', 'dir'), mkdir('trayectorias'); end
res = struct(); logs = struct();
for nombre = {'C1','C2','C3','C3b'}
    esc = escenario_qube(nombre{1});
    L = simular_qube(ctrl, est, esc, struct('semilla', 1));
    m = metricas_qube(L);
    res.(esc.nombre) = m; logs.(esc.nombre) = L;
    exportar_trayectoria(L, fullfile('trayectorias', [esc.nombre '.csv']));
    fprintf('%-4s  %-5s  J = %8.4f  ts = %6.3f s  max|u_c| = %6.2f V  max|theta| = %.3f rad\n', ...
        esc.nombre, m.estado, m.J, m.ts, m.max_uc, m.max_theta);
end
% C4: Monte Carlo (200 plantas en el trabajo; 20 en este ejemplo)
r4 = resumen_c4(ctrl, est, 20);
res.C4 = rmfield(r4, 'factores');
fprintf('C4    tasa de éxito = %d/%d\n', r4.n_exito, r4.n);
% C5: solo para controladores con levantamiento (E4)
res.C5 = struct('estado', 'no_aplica');
fid = fopen('results_ejemplo.json', 'w'); fprintf(fid, '%s', jsonencode(res)); fclose(fid);
% Videos (MATLAB con VideoWriter)
if exist('VideoWriter', 'file') == 2 || exist('VideoWriter', 'class') == 8
    animar_qube(logs.C1, struct('archivo', 'C1.mp4', 'tiempo_real', false));
    animar_qube(logs.C2, struct('archivo', 'C2.mp4', 'tiempo_real', false));
end
% Visor interactivo: compara C2 del diseño base con otro diseño
L2 = simular_qube(controlador_lineal(1.5*d.K0), est, escenario_qube('C2'), struct('semilla', 1));
animar_qube_interactivo({logs.C2, L2}, {'Diseño base', 'Diseño 1.5 K_0'});
