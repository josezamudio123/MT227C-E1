%E1_5_RESTRICCIONES  Inciso E1.5: optimización de los pesos con restricciones (dos niveles).
%
%   Nivel interno : pesos (Q, R0) -> LQR (icare) -> ganancia K.
%   Nivel externo : elegir los pesos que MINIMIZAN el costo OFICIAL del benchmark (Anexo B,
%                   metricas_qube) medido en el simulador OFICIAL (saturación, estimador base,
%                   encoders cuantizados, ruido de par, semilla fija 1) en C1, C2, C3 y C3b:
%                       Jrel(K) = media_c [ J_c(K) / J_c(K0) ],   c en {C1, C2, C3, C3b}
%                   (Jrel = 1 para el diseño base; < 1 es mejor).
%   Restricciones (especificación del grupo, 2026-11-08):
%     (R1) tasa de decaimiento  sigma = -max Re(eig(A-BK)) >= sigma_min = ln(0.05/0.02)/2 = 0.458 s^-1
%     (R2) amortiguamiento      zeta_min >= 0.5
%     (R3) C2 oficial: |theta| <= pi/2 en todo el ensayo y fracción de tiempo saturado <= 5 %
%     (R4) éxito (Anexo B) en C1, C2, C3 y C3b
%   Por qué este costo (y no el costo lineal J0 = tr(P X0)): J0 se minimiza exactamente con K0,
%   que ya cumple R1-R4 (primera formulación, ver anexo de IA); con saturación, estimador y
%   cuantización, K0 deja de ser necesariamente óptimo.
%
%   Etapas:
%     A) Malla de E1.4: factibilidad lineal + C2 (de la caché); costo oficial de los factibles.
%     B) Refinamiento con fminsearch (4 pesos: theta, alpha, dtheta, dalpha) desde dos puntos:
%        el diseño base y el mejor de la malla.
%     C) Predicción E1-P2: barrido de R = m*R0 con Q0 fijo.
%     D) Validación del óptimo frente al base con 20 semillas de ruido.
%   Requiere resultados/E1_4.mat y E1_4_sim.mat (de e1_4_pareto). Tarda unos 10 minutos; con la caché
%   (resultados/E1_5_cache.mat) menos de 1 minuto. Para recalcular: setappdata(0, 'E1_regenerar', true).

clear; clc; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
load(fullfile(raiz, 'resultados', 'E1_4.mat'), 'RTH', 'RAL', 'K', 'X0', 'NL', 'ib');
d = diseno_base_qube(); A = d.A; B = d.B; Q0 = d.Q0; R0 = d.R0; est = estimador_base(d);
cfg.sigma_min = log(0.05/0.02)/2; cfg.zeta_min = 0.5; cfg.sat_max = 0.05;
cfg.esc = {'C1', 'C2', 'C3', 'C3b'}; cfg.nrm = [(pi/4)^2, (pi/36)^2];
cfg.A = A; cfg.B = B; cfg.Q0 = Q0; cfg.R0 = R0; cfg.X0 = X0; cfg.est = est;
[cfg.Jb, mb] = J_oficial(d.K0, cfg, 1);                    % costo oficial del diseño base (semilla 1)
J0b = trace(icare(A, B, Q0, R0)*X0);
fprintf('Restricciones: sigma >= %.3f s^-1, zeta >= %.2f, C2 saturado <= %.0f %%, éxito en %s\n', ...
        cfg.sigma_min, cfg.zeta_min, 100*cfg.sat_max, strjoin(cfg.esc, ', '));
fprintf('Diseño base, costo oficial (semilla 1): J = %s  (C1, C2, C3, C3b)\n\n', mat2str(cfg.Jb, 4));

%% ===================== A) Malla de E1.4 =====================
N = numel(RTH); sg = zeros(N,1); zt = zeros(N,1);
for k = 1:N, [~, sg(k), zt(k)] = costo_polos(K(k,:), cfg); end
okR1 = sg >= cfg.sigma_min; okR2 = zt >= cfg.zeta_min;
okR3 = NL.exito(:,3) & NL.frac_sat(:,3) <= cfg.sat_max;
pre = find(okR1 & okR2 & okR3);
fprintf('=== A) Malla de E1.4 (%d diseños) ===\n', N);
fprintf('Cumplen R1: %d | R2: %d | R3 (C2 oficial): %d | R1-R3: %d\n', sum(okR1), sum(okR2), sum(okR3), numel(pre));
fprintf('Evaluando el costo oficial de los %d diseños que cumplen R1-R3...\n', numel(pre));
% Caché de las partes largas (A, B y D). run_all la usa salvo con E1_regenerar = true.
cache = fullfile(raiz, 'resultados', 'E1_5_cache.mat');
usar_cache = ~(isappdata(0, 'E1_regenerar') && getappdata(0, 'E1_regenerar')) && isfile(cache);
if usar_cache, C = load(cache); fprintf('(costo oficial de la malla, refinamiento y validación: caché %s)\n', cache); end
tic;
if usar_cache
    Jrel_g = C.Jrel_g; okR4 = C.okR4;
else
    Jrel_g = nan(N,1); okR4 = false(N,1);
    for k = pre'
        [Jv, ms] = J_oficial(K(k,:), cfg, 1);
        okR4(k) = all(cellfun(@(m) m.exito, ms));
        Jrel_g(k) = mean(Jv ./ cfg.Jb);
    end
end
fact = okR1 & okR2 & okR3 & okR4;
fprintf('Cumplen además R4 (éxito en los 4 escenarios): %d   (%.0f s)\n', sum(fact), toc);
jf = find(fact); [Jg, i] = min(Jrel_g(jf)); kg = jf(i);
fprintf('Mejor de la malla: r_th = %.3g, r_al = %.3g, Jrel = %.4f   (base: Jrel = 1)\n', RTH(kg), RAL(kg), Jg);
[~, orden] = sort(Jrel_g(jf));
fprintf('Cinco mejores de la malla (r_th, r_al, Jrel): %s\n\n', ...
        mat2str([RTH(jf(orden(1:min(5,end)))), RAL(jf(orden(1:min(5,end)))), Jrel_g(jf(orden(1:min(5,end))))], 3));

%% ===================== B) Refinamiento con fminsearch =====================
fprintf('=== B) Refinamiento (fminsearch, 4 pesos, dos puntos de partida) ===\n');
evaluar('reiniciar');
inicios = {log10([1, 1, 1e-6, 1e-6]), log10([RTH(kg), RAL(kg), 1e-6, 1e-6])};
nom_ini = {'diseño base', 'mejor de la malla'};
opt = optimset('MaxFunEvals', 200, 'TolX', 1e-3, 'TolFun', 1e-4, 'Display', 'off');
tic;
if usar_cache
    H = C.H; nB = C.nB; bJ = C.bJ;
else
    nB = zeros(1,2); bJ = inf(1,2);
    for s = 1:2
        n_ant = numel(evaluar('historial'));
        fminsearch(@(x) evaluar(x, cfg), inicios{s}, opt);
        H = evaluar('historial');
        nB(s) = numel(H) - n_ant;
        bJ(s) = min([H(n_ant+find([H(n_ant+1:end).factible])).Jrel inf]);
    end
    H = evaluar('historial');
end
for s = 1:2
    fprintf('Desde %-18s: %3d evaluaciones; mejor Jrel factible = %.4f\n', nom_ini{s}, nB(s), bJ(s));
end
hf = find([H.factible]);
[~, i] = min([H(hf).Jrel]); best = H(hf(i));
[J0o, ~, ~] = costo_polos(best.K, cfg);
fprintf('%d evaluaciones en %.0f s (%d factibles).\n', numel(H), toc, numel(hf));
fprintf('Diseño óptimo: pesos r = %s\n  K = %s   (K0 = %s)\n', mat2str(10.^best.x, 4), ...
        mat2str(best.K, 5), mat2str(d.K0, 5));
fprintf('  Jrel = %.4f  (J por escenario: %s)\n', best.Jrel, mat2str(best.Jv, 4));
fprintf('  sigma = %.3f, zeta = %.3f, polos = %s\n', best.sigma, best.zeta, mat2str(eig(A - B*best.K).', 4));
fprintf('  Costo lineal J0/J0b = %.4f (precio en el modelo lineal sin saturación)\n\n', J0o/J0b);

%% ===================== C) Predicción E1-P2: R = m*R0 con Q0 =====================
fprintf('=== C) Predicción E1-P2: R = m*R0 con Q = Q0 (C2 oficial, semilla 1) ===\n');
fprintf('%8s %10s %10s %10s %6s\n', 'm', 'K2 [V/rad]', 'max|th|', 'sat [%]', 'éxito');
ms_ = 10.^(0:0.25:3); bar_ = struct('m', ms_, 'K2', 0*ms_, 'th', 0*ms_, 'sat', 0*ms_, 'ex', false(size(ms_)));
for j = 1:numel(ms_)
    Kj = R0*ms_(j) \ (B'*icare(A, B, Q0, ms_(j)*R0));
    mm = metricas_qube(simular_qube(controlador_lineal(Kj), est, escenario_qube('C2'), struct('semilla', 1)));
    bar_.K2(j) = Kj(2); bar_.th(j) = mm.max_theta; bar_.sat(j) = 100*mm.frac_sat; bar_.ex(j) = mm.exito;
    fprintf('%8.2f %10.1f %10.3f %10.1f %6d\n', ms_(j), Kj(2), mm.max_theta, 100*mm.frac_sat, mm.exito);
end
fprintf('\n');

%% ===================== D) Validación con 20 semillas =====================
nsem = 20;
fprintf('=== D) Validación: base frente a óptimo, %d semillas de ruido ===\n', nsem);
dis = {d.K0, best.K}; nomd = {'base', 'óptimo'};
if usar_cache
    Jsem = C.Jsem; val = C.val;
else
    Jsem = zeros(nsem, 4, 2); val = struct();
    for q = 1:2
        okR3s = false(nsem,1); okR4s = false(nsem,1); sat = zeros(nsem,1); th = zeros(nsem,1); ts1 = nan(nsem,1);
        for s = 1:nsem
            [Jsem(s,:,q), ms] = J_oficial(dis{q}, cfg, s);
            okR4s(s) = all(cellfun(@(m) m.exito, ms));
            okR3s(s) = ms{2}.exito && ms{2}.frac_sat <= cfg.sat_max;
            sat(s) = ms{2}.frac_sat; th(s) = ms{2}.max_theta;
            if ~isempty(ms{1}.ts), ts1(s) = ms{1}.ts; end
        end
        val(q).okR3 = okR3s; val(q).okR4 = okR4s; val(q).sat = sat; val(q).th = th; val(q).ts = ts1;
    end
    save(cache, 'Jrel_g', 'okR4', 'H', 'nB', 'bJ', 'Jsem', 'val');
end
for q = 1:2
    fprintf('%-7s R3 en %2d/%d, R4 en %2d/%d | C2: saturado máx %.1f %%, max|theta| máx %.3f rad | ts(C1) máx %.3f s\n', ...
            nomd{q}, sum(val(q).okR3), nsem, sum(val(q).okR4), nsem, 100*max(val(q).sat), max(val(q).th), max(val(q).ts));
end
mejora = 1 - Jsem(:,:,2)./Jsem(:,:,1);                    % fracción de mejora por semilla y escenario
fprintf('\nMejora del óptimo sobre el base (1 - J_opt/J_base), media ± desv. est. en %d semillas:\n', nsem);
for c = 1:4
    fprintf('  %-4s %+6.1f %% ± %4.1f %%   (mejora en %d de %d semillas)\n', cfg.esc{c}, 100*mean(mejora(:,c)), ...
            100*std(mejora(:,c)), sum(mejora(:,c) > 0), nsem);
end
Jrel_s = mean(Jsem(:,:,2)./Jsem(:,:,1), 2);
fprintf('  Jrel medio: %.4f ± %.4f   (semilla 1, usada en la optimización: %.4f)\n', mean(Jrel_s), std(Jrel_s), best.Jrel);

%% Figuras
figure('Color', 'w', 'Position', [60 60 640 540]);
lr = log10([RTH RAL]);
plot(lr(:,1), lr(:,2), '.', 'Color', [0.8 0.8 0.8]); hold on;
scatter(lr(fact,1), lr(fact,2), 60, Jrel_g(fact), 's', 'filled');
xs = vertcat(H.x); plot(xs(:,1), xs(:,2), '-', 'Color', [0.85 0.33 0.1]);
plot(0, 0, 'kp', 'MarkerSize', 14, 'MarkerFaceColor', 'w');
plot(best.x(1), best.x(2), 'rp', 'MarkerSize', 16, 'MarkerFaceColor', 'r');
cb = colorbar; cb.Label.String = 'J_{rel} (costo oficial / base)'; grid on; axis square;
xlabel('log_{10} r_\theta'); ylabel('log_{10} r_\alpha');
legend('no factible', 'factible (R1-R4)', 'búsqueda fminsearch', 'diseño base', 'óptimo', ...
       'Location', 'southoutside', 'NumColumns', 3);
title('E1.5: costo oficial en la región factible');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_5_factibilidad.png'), 'Resolution', 200);

figure('Color', 'w', 'Position', [720 60 560 380]); rng(0);
for c = 1:4                                               % puntos por semilla + media ± desv. est.
    plot(c + 0.15*(rand(nsem,1) - 0.5), 100*mejora(:,c), 'o', 'Color', [0 0.45 0.74]); hold on;
    errorbar(c + 0.3, 100*mean(mejora(:,c)), 100*std(mejora(:,c)), 'ks', 'MarkerFaceColor', 'k', 'LineWidth', 1.2);
end
xlim([0.5 4.8]); xticks(1:4); xticklabels(cfg.esc); yline(0, 'k:'); grid on;
ylabel('mejora sobre el diseño base [%]');
title(sprintf('E1.5: validación con %d semillas de ruido', nsem));
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_5_validacion.png'), 'Resolution', 200);

figure('Color', 'w', 'Position', [720 500 560 380]);
yyaxis left; semilogx(ms_, bar_.sat, 'o-', 'LineWidth', 1.3); ylabel('fracción saturada en C2 [%]');
yline(100*cfg.sat_max, '--', '5 %');
yyaxis right; semilogx(ms_, bar_.th, 's-', 'LineWidth', 1.3); ylabel('max|\theta| en C2 [rad]');
yline(pi/2, ':', '\pi/2'); grid on; xlabel('m  (R = m R_0, Q = Q_0)');
title('E1.5: predicción E1-P2 (barrido de R)');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_5_barrido_R.png'), 'Resolution', 200);

K_opt = best.K;
save(fullfile(raiz, 'resultados', 'E1_5.mat'), 'K_opt', 'best', 'H', 'cfg', 'Jrel_g', 'fact', 'okR1', 'okR2', ...
     'okR3', 'okR4', 'bar_', 'val', 'Jsem', 'mejora', 'J0o', 'J0b');
fprintf('\nGuardado: resultados/E1_5.mat y figuras E1_5_factibilidad, E1_5_validacion, E1_5_barrido_R\n');

%% ======================= Funciones locales =======================
function [Jv, ms] = J_oficial(K, cfg, semilla)
% Costo del Anexo B en el simulador oficial (estimador, cuantización, ruido) para cada escenario.
ctrl = controlador_lineal(K); Jv = nan(1, numel(cfg.esc)); ms = cell(1, numel(cfg.esc));
for c = 1:numel(cfg.esc)
    ms{c} = metricas_qube(simular_qube(ctrl, cfg.est, escenario_qube(cfg.esc{c}), struct('semilla', semilla)));
    if ~isempty(ms{c}.J), Jv(c) = ms{c}.J; end
end
end

function [J0, sigma, zeta] = costo_polos(K, cfg)
Acl = cfg.A - cfg.B*K;
J0 = trace(lyap_kron(Acl', cfg.Q0 + K'*cfg.R0*K)*cfg.X0);
lam = eig(Acl); sigma = -max(real(lam));
c = lam(abs(imag(lam)) > 1e-9);
if isempty(c), zeta = 1; else, zeta = min(-real(c)./abs(c)); end
end

function f = evaluar(x, cfg)
% Evalúa un vector de pesos (log10) y guarda el historial.
% evaluar('reiniciar') vacía el historial; evaluar('historial') lo devuelve.
persistent H
if ischar(x)
    if strcmp(x, 'reiniciar'), H = struct([]); f = []; else, f = H; end
    return
end
x = min(max(x, -6), 6);
r = 10.^x;
Q = diag([r(1)/cfg.nrm(1), r(2)/cfg.nrm(2), r(3), r(4)]);
K = cfg.R0 \ (cfg.B'*icare(cfg.A, cfg.B, Q, cfg.R0));
[~, sigma, zeta] = costo_polos(K, cfg);
[Jv, ms] = J_oficial(K, cfg, 1);
ex = cellfun(@(m) m.exito, ms);
viol = max(0, cfg.sigma_min - sigma)/cfg.sigma_min + max(0, cfg.zeta_min - zeta)/cfg.zeta_min ...
     + max(0, ms{2}.frac_sat - cfg.sat_max)/cfg.sat_max + max(0, ms{2}.max_theta - pi/2)/(pi/2) + sum(~ex);
Jrel = mean(Jv ./ cfg.Jb);
if ~isfinite(Jrel), Jrel = 10; end
f = Jrel + 10*viol;
e = struct('x', x, 'K', K, 'Jv', Jv, 'Jrel', Jrel, 'sigma', sigma, 'zeta', zeta, 'viol', viol, 'factible', viol == 0);
if isempty(H), H = e; else, H(end+1) = e; end
end
