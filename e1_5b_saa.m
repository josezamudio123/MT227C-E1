%E1_5B_SAA  Inciso E1.5 (corrección de método): optimización con PROMEDIO de semillas y
%   validación con semillas INDEPENDIENTES.
%
%   Motivo: en e1_5_restricciones el costo se optimizó con una sola realización del ruido
%   (semilla 1): Jrel = 0.961 con esa semilla, pero 0.9945 ± 0.019 en 20 semillas; parte de la
%   "mejora" era sobreajuste a esa realización.
%   Método (aproximación por promedio muestral):
%     - Objetivo: Jrel(K) = promedio sobre las semillas 1..5 de  media_c J_c(K,s)/J_c(K0,s),
%       c en {C1, C2, C3, C3b}, simulador oficial (estimador, cuantización, ruido).
%       Base y candidato se comparan con la MISMA semilla (números aleatorios comunes).
%     - Restricciones R1-R4 (como en e1_5_restricciones); R3 y R4 deben cumplirse en las 5 semillas.
%     - Búsqueda: malla 9 x 9 en log10(r_th), log10(r_al) de -0.4 a 1.2 (pesos de las velocidades
%       nulos, porque fminsearch los llevó al mínimo), más el óptimo previo de semilla 1.
%     - Validación: semillas 101..120, que NO se usaron para elegir; comparación pareada con el
%       base (estadístico t con 19 grados de libertad; |t| > 2.09 es significativo al 5 %).
%   Requiere resultados/E1_5.mat (de e1_5_restricciones). Tarda unos 11 minutos; con la caché
%   (resultados/E1_5b_cache.mat) unos segundos. Para recalcular: setappdata(0, 'E1_regenerar', true).

clear; clc; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
load(fullfile(raiz, 'resultados', 'E1_5.mat'), 'cfg', 'best');
d = diseno_base_qube(); A = cfg.A; B = cfg.B; R0 = cfg.R0;
sem_opt = 1:5; sem_val = 101:120; t_crit = 2.093;

cache = fullfile(raiz, 'resultados', 'E1_5b_cache.mat');
usar_cache = ~(isappdata(0, 'E1_regenerar') && getappdata(0, 'E1_regenerar')) && isfile(cache);
if usar_cache, C = load(cache); fprintf('(malla y validación: caché %s)\n', cache); end

%% Costo del diseño base en las semillas de optimización
if usar_cache
    Jb = C.Jb;
else
    Jb = zeros(numel(sem_opt), 4);
    for i = 1:numel(sem_opt), Jb(i,:) = J_oficial(d.K0, cfg, sem_opt(i)); end
end

%% Malla 9 x 9 (+ óptimo previo)
g = linspace(-0.4, 1.2, 9);
[GT, GA] = meshgrid(g, g); X = [GT(:), GA(:)];
X(end+1,:) = best.x(1:2);                                % óptimo previo (semilla 1)
nX = size(X, 1);
if usar_cache
    Jm = C.Jm; Jse = C.Jse; fac = C.fac; Kx = C.Kx; sg = C.sg; zt = C.zt;
else
    Jm = nan(nX,1); Jse = nan(nX,1); fac = false(nX,1); Kx = zeros(nX,4); sg = zeros(nX,1); zt = zeros(nX,1);
    fprintf('Evaluando %d diseños x %d semillas x 4 escenarios...\n', nX, numel(sem_opt)); tic;
    for k = 1:nX
        r = 10.^X(k,:);
        Q = diag([r(1)/cfg.nrm(1), r(2)/cfg.nrm(2), 0, 0]);
        Kx(k,:) = R0 \ (B'*icare(A, B, Q, R0));
        [sg(k), zt(k)] = polos(Kx(k,:), A, B);
        if sg(k) < cfg.sigma_min || zt(k) < cfg.zeta_min, continue; end      % R1, R2
        Jr = zeros(numel(sem_opt),1); ok = true;
        for i = 1:numel(sem_opt)
            [Jv, ms] = J_oficial(Kx(k,:), cfg, sem_opt(i));
            ok = ok && all(cellfun(@(m) m.exito, ms)) && ms{2}.frac_sat <= cfg.sat_max;   % R3, R4
            Jr(i) = mean(Jv ./ Jb(i,:));
        end
        fac(k) = ok; Jm(k) = mean(Jr); Jse(k) = std(Jr)/sqrt(numel(Jr));
        if mod(k, 10) == 0, fprintf('  %d/%d (%.0f s)\n', k, nX, toc); end
    end
end
jf = find(fac); [~, i] = min(Jm(jf)); kb = jf(i);
k00 = find(abs(X(:,1)) < 1e-12 & abs(X(:,2)) < 1e-12);    % el diseño base está en la malla
fprintf('\nFactibles: %d de %d.  Base (malla): Jrel = %.4f ± %.4f\n', sum(fac), nX, Jm(k00), Jse(k00));
fprintf('Óptimo SAA: log10 r = [%.2f %.2f] (r_th = %.3g, r_al = %.3g), Jrel = %.4f ± %.4f (5 semillas)\n', ...
        X(kb,:), 10.^X(kb,:), Jm(kb), Jse(kb));
fprintf('Óptimo previo (semilla 1): Jrel = %.4f ± %.4f en las semillas 1..5\n', Jm(nX), Jse(nX));
[~, ord] = sort(Jm(jf));
fprintf('Cinco mejores (log10 r_th, log10 r_al, Jrel, error estándar):\n'); disp([X(jf(ord(1:5)),:), Jm(jf(ord(1:5))), Jse(jf(ord(1:5)))]);
K_saa = Kx(kb,:);
fprintf('K_saa = %s   (K0 = %s)\n', mat2str(K_saa, 5), mat2str(d.K0, 5));
fprintf('sigma = %.3f, zeta = %.3f\n\n', sg(kb), zt(kb));

%% Validación con semillas independientes 101..120
fprintf('=== Validación con semillas %d..%d (no usadas para elegir) ===\n', sem_val(1), sem_val(end));
dis = {d.K0, K_saa, best.K}; nomd = {'base', 'óptimo SAA', 'óptimo semilla 1'};
if usar_cache
    Jv_ = C.Jv_; ok3 = C.ok3; thm = C.thm;
else
    Jv_ = zeros(numel(sem_val), 4, 3); ok3 = false(numel(sem_val), 3); thm = zeros(numel(sem_val), 3);
    for q = 1:3
        for s = 1:numel(sem_val)
            [Jv_(s,:,q), ms] = J_oficial(dis{q}, cfg, sem_val(s));
            ok3(s,q) = all(cellfun(@(m) m.exito, ms)) && ms{2}.frac_sat <= cfg.sat_max;
            thm(s,q) = ms{2}.max_theta;
        end
    end
    save(cache, 'Jb', 'Jm', 'Jse', 'fac', 'Kx', 'sg', 'zt', 'Jv_', 'ok3', 'thm');
end
for q = 2:3
    mej = 1 - Jv_(:,:,q)./Jv_(:,:,1);
    jr = mean(Jv_(:,:,q)./Jv_(:,:,1), 2);
    tJ = (1 - mean(jr)) / (std(jr)/sqrt(numel(jr)));
    fprintf('\n%s: R3-R4 en %d de %d semillas; C2 max|theta| máx %.3f rad (base %.3f)\n', nomd{q}, ...
            sum(ok3(:,q)), numel(sem_val), max(thm(:,q)), max(thm(:,1)));
    for c = 1:4
        tc = mean(mej(:,c)) / (std(mej(:,c))/sqrt(size(mej,1)));
        fprintf('  %-4s mejora %+6.1f %% ± %4.1f %%  (t = %+6.2f, %s; mejora en %2d de %d)\n', cfg.esc{c}, ...
                100*mean(mej(:,c)), 100*std(mej(:,c)), tc, ternario(abs(tc) > t_crit, 'significativo', 'no significativo'), ...
                sum(mej(:,c) > 0), size(mej,1));
    end
    fprintf('  Jrel = %.4f ± %.4f  (t = %+.2f, %s)\n', mean(jr), std(jr), tJ, ...
            ternario(abs(tJ) > t_crit, 'significativo', 'no significativo'));
end

%% Figuras
figure('Color', 'w', 'Position', [60 60 620 520]);
Z = reshape(Jm(1:81), 9, 9); Z(~reshape(fac(1:81), 9, 9)) = NaN;
imagesc(g, g, Z, 'AlphaData', ~isnan(Z)); set(gca, 'YDir', 'normal'); axis square; hold on;
cb = colorbar; cb.Label.String = 'J_{rel} medio (semillas 1-5)';
plot(0, 0, 'kp', 'MarkerSize', 14, 'MarkerFaceColor', 'w');
plot(X(kb,1), X(kb,2), 'rp', 'MarkerSize', 16, 'MarkerFaceColor', 'r');
plot(X(nX,1), X(nX,2), 'm^', 'MarkerSize', 10, 'MarkerFaceColor', 'm');
xlabel('log_{10} r_\theta'); ylabel('log_{10} r_\alpha'); grid on;
legend('diseño base', 'óptimo SAA', 'óptimo semilla 1', 'Location', 'southoutside', 'NumColumns', 3);
title('E1.5: costo oficial promediado en 5 semillas (blanco: no factible)');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_5_saa.png'), 'Resolution', 200);

figure('Color', 'w', 'Position', [700 60 620 380]); rng(0);
mej = 1 - Jv_(:,:,2)./Jv_(:,:,1);
for c = 1:4
    plot(c + 0.15*(rand(size(mej,1),1) - 0.5), 100*mej(:,c), 'o', 'Color', [0 0.45 0.74]); hold on;
    errorbar(c + 0.3, 100*mean(mej(:,c)), 100*std(mej(:,c)), 'ks', 'MarkerFaceColor', 'k', 'LineWidth', 1.2);
end
xlim([0.5 4.8]); xticks(1:4); xticklabels(cfg.esc); yline(0, 'k:'); grid on;
ylabel('mejora sobre el diseño base [%]');
title('E1.5: óptimo SAA, validación con semillas 101-120');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_5_saa_validacion.png'), 'Resolution', 200);

save(fullfile(raiz, 'resultados', 'E1_5b.mat'), 'K_saa', 'X', 'Jm', 'Jse', 'fac', 'Kx', 'sg', 'zt', 'kb', ...
     'Jv_', 'ok3', 'thm', 'sem_opt', 'sem_val');
fprintf('\nGuardado: resultados/E1_5b.mat, figuras/E1_5_saa.png, figuras/E1_5_saa_validacion.png\n');

%% ======================= Funciones locales =======================
function [Jv, ms] = J_oficial(K, cfg, semilla)
ctrl = controlador_lineal(K); Jv = nan(1, numel(cfg.esc)); ms = cell(1, numel(cfg.esc));
for c = 1:numel(cfg.esc)
    ms{c} = metricas_qube(simular_qube(ctrl, cfg.est, escenario_qube(cfg.esc{c}), struct('semilla', semilla)));
    if ~isempty(ms{c}.J), Jv(c) = ms{c}.J; end
end
end

function [sigma, zeta] = polos(K, A, B)
lam = eig(A - B*K); sigma = -max(real(lam));
c = lam(abs(imag(lam)) > 1e-9);
if isempty(c), zeta = 1; else, zeta = min(-real(c)./abs(c)); end
end

function s = ternario(c, a, b)
if c, s = a; else, s = b; end
end
