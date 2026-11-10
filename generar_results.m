%GENERAR_RESULTS  Arma results.json (Anexo A de la guía) a partir de los resultados guardados
%   y lo valida con validar_results del kit. Todos los números salen de resultados/*.mat, que
%   generan los scripts del encargo; ninguno se escribe a mano.
%   Convenciones: matrices como listas de filas; escalares en SI; valores no definidos como null
%   (NaN en MATLAB se escribe como null). Los autovalores complejos se guardan como pares
%   [parte real, parte imaginaria].

clear; clc;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
R = @(f) load(fullfile(raiz, 'resultados', f));
d = diseno_base_qube();
mp = load(fullfile(raiz, 'modelo_propio.mat')); mp = mp.modelo;
e11 = R('E1_1.mat'); e16 = R('E1_6.mat'); sc = R('escenarios.mat');
[K, info] = diseno_final();

s = struct();
s.grupo = 'MT227C-E1 (Zamudio Salazar, Joseluis Omar; Nava Laburiano, David Adrián)';
s.software = sprintf('MATLAB %s; Symbolic Math, Control System y Robust Control Toolbox; kit MT227C v1.1.1', version);
s.semillas = struct('escenarios_C1_C3b', 1, 'C4_plantas', '1000+i, i = 1..200', 'C4_ruido', 'i, i = 1..200', ...
                    'E1_5_optimizacion', 1:5, 'E1_5_validacion', 101:120, 'E1_6_montecarlo', e16.mc_region.semilla);
% Modelo propio (modelo_propio.m) y diseño base del kit
s.A = mp.A; s.B = mp.B; s.eig_A = sort(real(mp.eig_A)); s.A5 = mp.A5; s.B5 = mp.B5;
s.polo_electrico = mp.polo_electrico; s.K0 = d.K0; s.L_base = d.L0;
% E1
r2 = e11.res(2);                                         % problema 2 de E1.1: diseño base (Q0, R0)
s.resid_care = struct('hamiltoniana', r2.residuo(1), 'schur', r2.residuo(2), 'newton_kleinman', r2.residuo(3));
s.K_opt = K;
lam = eig(d.A - d.B*K); [~, o] = sort(real(lam), 'descend'); lam = lam(o);
s.eig_cl_opt = [real(lam), imag(lam)];
s.eig_cl_opt_formato = '[parte real, parte imaginaria]';
s.K_opt_criterio = info.nombre;
s.rho_elipse = e16.rho;
s.mc_region = e16.mc_region;
% Escenarios
for c = {'C1', 'C2', 'C3', 'C3b'}
    m = sc.esc.(c{1});
    s.(c{1}) = struct('estado', m.estado, 'J', nulo(m.J), 'ts', nulo(m.ts), 'max_uc', m.max_uc, 'max_u', m.max_u, ...
                      'frac_sat', m.frac_sat, 'max_theta', m.max_theta, 'exito', m.exito, ...
                      'violacion_duracion', m.violacion_duracion, 'violacion_magnitud', m.violacion_magnitud, ...
                      'rmse_alpha', m.rmse_alpha, 'rmse_dalpha', m.rmse_dalpha);
end
r4 = sc.r4; r4 = rmfield(r4, 'factores');
for f = {'J', 'ts', 'max_uc', 'max_theta'}
    for g = {'media', 'desv', 'p95'}, r4.(f{1}).(g{1}) = nulo(r4.(f{1}).(g{1})); end
end
s.C4 = r4;
s.C5 = struct('estado', 'no_aplica');
% Números que cita el informe (fichas, predicciones, pruebas), registrados con anotar por cada script
anotar('esc_C2_sat', s.C2.frac_sat, 'p1'); anotar('esc_C2_th', s.C2.max_theta, 'f3');
Vi = load(fullfile(raiz, 'resultados', 'valores_informe.mat')); Vi = Vi.V;
claves = fieldnames(Vi);
for i = 1:numel(claves), s.valores_informe.(claves{i}) = Vi.(claves{i}).valor; end

archivo = fullfile(raiz, 'results.json');
fid = fopen(archivo, 'w'); fprintf(fid, '%s', jsonencode(s, 'PrettyPrint', true)); fclose(fid);
fprintf('Escrito: %s\n\n', archivo);
validar_results(archivo, 'E1');


%% Tabla de escenarios para el informe, leída DEL MISMO results.json (sin copiar números a mano)
r = jsondecode(fileread(archivo));
ft = fopen(fullfile(raiz, 'informe', 'tabla_escenarios.tex'), 'w');
fprintf(ft, '%% Generado automáticamente por generar_results.m desde results.json. No editar a mano.\n');
fprintf(ft, '\\begin{center}\\small\\setlength{\\tabcolsep}{3.5pt}\n\\begin{tabular}{@{}l l r r r r r r@{}}\n\\toprule\n');
fprintf(ft, 'Escenario & Estado & $J$ & $t_s$ [s] & $\\max|u_c|$ [V] & $\\max|u|$ [V] & Saturado [\\%%] & $\\max|\\theta|$ [rad] \\\\\n\\midrule\n');
for c = {'C1', 'C2', 'C3', 'C3b'}
    m = r.(c{1});
    fprintf(ft, '%s & %s & %.4f & %s & %.2f & %.2f & %.1f & %.3f \\\\\n', c{1}, m.estado, m.J, num_o_null(m.ts, '%.3f'), ...
            m.max_uc, m.max_u, 100*m.frac_sat, m.max_theta);
end
c4 = r.C4;
fprintf(ft, '\\midrule\nC4 & %d de %d & %.4f $\\pm$ %.4f & %.3f (p95) & %.2f & -- & -- & %.3f (p95) \\\\\n', ...
        c4.n_exito, c4.n, c4.J.media, c4.J.desv, c4.ts.p95, c4.max_uc.media, c4.max_theta.p95);
fprintf(ft, 'C5 & %s & \\multicolumn{6}{l}{(solo se exige a E4)} \\\\\n\\bottomrule\n\\end{tabular}\n\\end{center}\n', ...
        strrep(r.C5.estado, '_', '\_'));
fclose(ft);
fprintf('Escrito: informe/tabla_escenarios.tex (desde results.json)\n');

%% Valores citados en el informe, leídos DEL MISMO results.json (el informe los usa con \V{clave})
fv = fopen(fullfile(raiz, 'informe', 'valores_E1.tex'), 'w');
fprintf(fv, '%% Generado automáticamente por generar_results.m desde results.json (clave valores_informe). No editar a mano.\n');
fprintf(fv, '\\providecommand{\\V}[1]{\\ifcsname val@#1\\endcsname\\csname val@#1\\endcsname\\else\\textbf{??\\detokenize{#1}??}\\fi}\n');
for i = 1:numel(claves)
    v = r.valores_informe.(claves{i});
    if isempty(v), v = NaN; end
    fprintf(fv, '\\expandafter\\def\\csname val@%s\\endcsname{%s}\n', claves{i}, fmt_tex(v, Vi.(claves{i}).formato));
end
fclose(fv);
% Comprobación: toda clave \V{...} que usa el informe existe en results.json
txt = '';
for f = {'informe_E1.tex', 'fichas_E1.tex', 'predicciones_E1.tex', 'pruebas_conocidas_E1.tex'}
    txt = [txt fileread(fullfile(raiz, 'informe', f{1}))]; %#ok<AGROW>
end
tok = regexp(txt, '\\V\{(\w+)\}', 'tokens');
usadas = unique(cellfun(@(c) c{1}, tok, 'UniformOutput', false));
faltan = setdiff(usadas, claves);
fprintf('Escrito: informe/valores_E1.tex (%d valores; el informe usa %d)\n', numel(claves), numel(usadas));
if isempty(faltan)
    fprintf('Todas las claves que usa el informe están en results.json.\n');
else
    warning('Claves usadas en el informe que NO están en results.json: %s', strjoin(faltan, ', '));
end

function s = num_o_null(x, fmt)
if isempty(x) || (isnumeric(x) && isnan(x)), s = 'null'; else, s = sprintf(fmt, x); end
end

function t = fmt_tex(x, f)
%FMT_TEX  Número -> texto LaTeX (modo matemático) según el formato declarado en anotar.
if ~isfinite(x), t = '\mathrm{null}'; return; end
n = str2double(f(2:end)); if isnan(n), n = 0; end
switch f(1)
    case 'e'
        if x == 0, t = '0'; return; end
        ex = floor(log10(abs(x))); m = round(x/10^ex, n);
        if abs(m) >= 10, m = m/10; ex = ex + 1; end
        t = sprintf('%.*f', n, m);
        if ex ~= 0, t = sprintf('%s\\times10^{%d}', t, ex); end
    case 'f', t = sprintf('%.*f', n, x);
    case 'p', t = sprintf('%.*f', n, 100*x);
    case 'g', t = sprintf('%.*g', n, x);
    case 'd'
        t = sprintf('%d', round(x));
        if abs(round(x)) >= 10000, t = regexprep(t, '(\d)(?=(\d{3})+$)', '$1\\,'); end
    otherwise, error('fmt_tex: formato desconocido: %s', f);
end
end

function v = nulo(x)
if isempty(x), v = NaN; else, v = x; end
end
