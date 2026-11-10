%RUN_ALL  Regenera TODOS los resultados, figuras, tablas y results.json del encargo E1 desde el
%   código fuente (guía, sección 2.6).
%
%   regenerar = false : usa las cachés permitidas por la guía (cálculos largos con semilla fija):
%       resultados/E1_3_ref.mat     referencias en precisión extendida (vpa)       ~5 min
%       resultados/E1_4_sim.mat     1875 simulaciones no lineales de la malla      ~5 min
%       resultados/E1_5_cache.mat   optimización con fminsearch y validación       ~10 min
%       resultados/E1_5b_cache.mat  malla con 5 semillas y validación              ~11 min
%   regenerar = true  : recalcula todo, incluidas las cachés (unos 50 minutos).
%   Todo lo demás (modelo, pruebas, E1.1-E1.6, LMI, escenarios C1-C4, videos y results.json) se
%   calcula siempre. Al final se valida results.json con el validador del kit.

regenerar = false;

raiz_ra = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz_ra, 'kit'), fullfile(raiz_ra, 'src'));
setappdata(0, 'E1_regenerar', regenerar);
pasos = {'modelo_propio', 'pruebas_kit', 'pruebas_E1', 'e1_1_metodos', 'e1_2_verificacion', ...
         'e1_3_estres', 'e1_3b_balanceo', 'e1_3c_icare', 'e1_3d_escalado', 'e1_3e_icare_escalado', ...
         'e1_4_pareto', 'e1_5_restricciones', 'e1_5b_saa', 'e1_5c_sensibilidad', 'e1_5d_lmi', ...
         'e1_6_region', 'escenarios_E1', 'generar_results'};
tiempos = zeros(1, numel(pasos)); estado = repmat({'ok'}, 1, numel(pasos));
vinf = fullfile(raiz_ra, 'resultados', 'valores_informe.mat');   % números del informe: se rearman desde cero
if isfile(vinf), delete(vinf); end
diario = fullfile(raiz_ra, 'resultados', 'run_all_log.txt');
if isfile(diario), delete(diario); end
diary(diario);
t_total = tic;
for i = 1:numel(pasos)
    fprintf('\n################ [%d/%d] %s ################\n', i, numel(pasos), pasos{i});
    t_i = tic;
    try
        ejecutar_paso(raiz_ra, pasos{i});
    catch err
        estado{i} = ['FALLA: ' err.message];
        fprintf(2, 'FALLA en %s: %s\n', pasos{i}, err.message);
    end
    tiempos(i) = toc(t_i);
    close all;
end
fprintf('\n================ RESUMEN DE run_all ================\n');
for i = 1:numel(pasos)
    fprintf('%-22s %7.1f s   %s\n', pasos{i}, tiempos(i), estado{i});
end
fprintf('Tiempo total: %.1f min (límite de la guía: 30 min). Cachés: %s\n', toc(t_total)/60, ...
        ternario_ra(regenerar, 'recalculadas', 'usadas'));
diary off;
rmappdata(0, 'E1_regenerar');

function ejecutar_paso(raiz, nombre)
% Cada script corre en el espacio de trabajo de ESTA función: su "clear" no borra las variables
% de run_all.
if strcmp(nombre, 'pruebas_kit')
    dir_ant = cd(fullfile(raiz, 'kit')); limpia = onCleanup(@() cd(dir_ant));
    pruebas_kit;
else
    run(fullfile(raiz, [nombre '.m']));
end
end

function s = ternario_ra(c, a, b)
if c, s = a; else, s = b; end
end
