%E1_5D_LMI  Bonificación de E1.5: síntesis por regiones de polos con LMI (Chilali y Gahinet,
%   1996) frente al ajuste de pesos (Q, R), y costo de imponer la región.
%
%   Herramienta: src/lqr_region_lmi.m (LMI Lab, Robust Control Toolbox). Minimiza una cota del
%   costo del benchmark J0 = tr(P X0) con (Q0, R0, X0 de E1.4) sujeto a que los polos de A - BK
%   estén en la región D = {Re(s) <= -sigma} intersección {zeta >= zeta_min}.
%   Pruebas y experimentos:
%     0) Respuesta conocida: sin región, la LMI debe reproducir el LQR (K0) y su costo J0b.
%     1) Región del grupo (sigma = 0.458, zeta = 0.5): costo y polos.
%     2) Barridos de la región: sigma de 0.458 a 6 (zeta = 0.5) y zeta de 0.5 a 0.95 (sigma = 0.458).
%        Para cada región: (a) LMI: cota tr(Z) y costo real J0(K_lmi); (b) mejor LQR de la malla de
%        E1.4 que cae en la región (ajuste de Q). "Costo de imponer la región" = J0/J0b - 1.
%     3) Verificación no lineal (simulador oficial, semillas 1..5) del diseño LMI en dos regiones.
%   Requiere resultados/E1_4.mat y E1_5.mat.

clear; clc; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
load(fullfile(raiz, 'resultados', 'E1_4.mat'), 'K', 'X0');
load(fullfile(raiz, 'resultados', 'E1_5.mat'), 'cfg');
d = diseno_base_qube(); A = d.A; B = d.B; Q0 = d.Q0; R0 = d.R0;
J0f = @(Kx) trace(lyap_kron((A - B*Kx)', Q0 + Kx'*R0*Kx)*X0);
J0b = J0f(d.K0);
erel = @(X, Y) norm(X - Y)/norm(Y);

%% 0) Respuesta conocida: sin región = LQR
[K_l, Jc, inf0] = lqr_region_lmi(A, B, Q0, R0, X0);
fprintf('=== 0) Sin región (debe reproducir el LQR) ===\n');
fprintf('K_lmi = %s\nK0    = %s\nerror relativo = %.1e;  cota tr(Z)/J0b = %.6f;  J0(K_lmi)/J0b = %.6f\n\n', ...
        mat2str(K_l, 6), mat2str(d.K0, 6), erel(K_l, d.K0), Jc/J0b, J0f(K_l)/J0b);

%% 1) Región del grupo
reg = struct('sigma', cfg.sigma_min, 'zeta', cfg.zeta_min);
[K_g, Jc_g, inf_g] = lqr_region_lmi(A, B, Q0, R0, X0, reg);
[sg_g, zt_g] = sig_zeta(inf_g.polos);
fprintf('=== 1) Región del grupo (sigma >= %.3f, zeta >= %.2f) ===\n', reg.sigma, reg.zeta);
fprintf('K_lmi = %s\npolos = %s  (sigma = %.3f, zeta = %.3f)\n', mat2str(K_g, 5), mat2str(inf_g.polos.', 4), sg_g, zt_g);
fprintf('cota/J0b = %.4f, J0(K_lmi)/J0b = %.4f  -> costo de imponer la región: %+.2f %%\n', Jc_g/J0b, J0f(K_g)/J0b, 100*(J0f(K_g)/J0b - 1));
[sb, zb] = sig_zeta(eig(A - B*d.K0));
fprintf('(el diseño base ya está en la región: sigma = %.3f, zeta = %.3f)\n\n', sb, zb);

%% 2) Barridos de la región
N = size(K, 1); sgm = zeros(N,1); ztm = zeros(N,1); J0m = zeros(N,1);
for k = 1:N, [sgm(k), ztm(k)] = sig_zeta(eig(A - B*K(k,:))); J0m(k) = J0f(K(k,:)); end
barr = {struct('nombre', 'sigma', 'val', [0.458 1 2 2.668 3 4 5 6], 'fijo', cfg.zeta_min), ...
        struct('nombre', 'zeta',  'val', [0.5 0.6 0.7 0.742 0.8 0.85 0.9 0.95], 'fijo', cfg.sigma_min)};
res = struct();
for b = 1:2
    v = barr{b}.val; nv = numel(v);
    Jl = nan(nv,1); Jcl = nan(nv,1); Jq = nan(nv,1); ach = nan(nv,2); Kl = nan(nv,4);
    fprintf('=== 2.%d) Barrido de %s (%s fijo) ===\n', b, barr{b}.nombre, ternario(b == 1, 'zeta', 'sigma'));
    fprintf('%7s | %10s %10s %16s | %12s\n', barr{b}.nombre, 'cota/J0b', 'J0lmi/J0b', 'sigma, zeta lmi', 'mejor LQR/J0b');
    for i = 1:nv
        if b == 1, rg = struct('sigma', v(i), 'zeta', barr{b}.fijo); else, rg = struct('sigma', barr{b}.fijo, 'zeta', v(i)); end
        [Kx, Jc_, inf_] = lqr_region_lmi(A, B, Q0, R0, X0, rg);
        if inf_.factible
            Kl(i,:) = Kx; Jcl(i) = Jc_/J0b; Jl(i) = J0f(Kx)/J0b; [ach(i,1), ach(i,2)] = sig_zeta(inf_.polos);
        end
        enreg = sgm >= rg.sigma - 1e-9 & ztm >= rg.zeta - 1e-9;
        if any(enreg), Jq(i) = min(J0m(enreg))/J0b; end
        fprintf('%7.3f | %10.4f %10.4f %7.3f, %6.3f | %12.4f\n', v(i), Jcl(i), Jl(i), ach(i,1), ach(i,2), Jq(i));
    end
    res(b).v = v; res(b).Jl = Jl; res(b).Jcl = Jcl; res(b).Jq = Jq; res(b).ach = ach; res(b).Kl = Kl;
    fprintf('\n');
end

%% 3) Verificación no lineal (simulador oficial, semillas 1..5)
fprintf('=== 3) Verificación no lineal del diseño LMI (simulador oficial, semillas 1..5) ===\n');
reg_t = struct('sigma', 4, 'zeta', cfg.zeta_min);                    % región exigente (sigma por encima del base)
[K_t, ~, inf_t] = lqr_region_lmi(A, B, Q0, R0, X0, reg_t);
cand = {d.K0, K_g, K_t}; nomc = {'base K0', 'LMI región grupo', 'LMI sigma >= 4'};
Jb = zeros(5,4); for s = 1:5, Jb(s,:) = J_oficial(d.K0, cfg, s); end
for q = 1:3
    jr = zeros(5,1); ok = true; satm = 0;
    for s = 1:5
        [Jv, ms] = J_oficial(cand{q}, cfg, s);
        jr(s) = mean(Jv ./ Jb(s,:));
        ok = ok && all(cellfun(@(m) m.exito, ms)) && ms{2}.frac_sat <= cfg.sat_max;
        satm = max(satm, ms{2}.frac_sat);
    end
    jr5(q,:) = [mean(jr) std(jr)];
    fprintf('%-18s K = %-40s Jrel = %.4f ± %.4f | R3-R4 en las 5 semillas: %d | sat. máx C2 %.1f %%\n', nomc{q}, ...
            mat2str(cand{q}, 4), mean(jr), std(jr), ok, 100*satm);
end

%% 4) Validación del diseño LMI de la región del grupo con semillas independientes 101..120
%   (misma regla de decisión que en E1.5: cambiar K0 solo si la mejora es significativa)
sem_val = 101:120; t_crit = 2.093;
fprintf('\n=== 4) Validación del diseño LMI (región del grupo), semillas %d..%d ===\n', sem_val(1), sem_val(end));
Jv0 = zeros(numel(sem_val), 4); Jvg = Jv0; okg = false(numel(sem_val),1); thg = zeros(numel(sem_val),1); th0 = thg;
for s = 1:numel(sem_val)
    [Jv0(s,:), m0] = J_oficial(d.K0, cfg, sem_val(s));
    [Jvg(s,:), mg] = J_oficial(K_g, cfg, sem_val(s));
    okg(s) = all(cellfun(@(m) m.exito, mg)) && mg{2}.frac_sat <= cfg.sat_max;
    thg(s) = mg{2}.max_theta; th0(s) = m0{2}.max_theta;
end
mej = 1 - Jvg./Jv0; jr = mean(Jvg./Jv0, 2);
fprintf('R3-R4 en %d de %d semillas; C2 max|theta| máx %.3f rad (base %.3f)\n', sum(okg), numel(sem_val), max(thg), max(th0));
for c = 1:4
    tc = mean(mej(:,c))/(std(mej(:,c))/sqrt(size(mej,1)));
    fprintf('  %-4s mejora %+6.1f %% ± %4.1f %%  (t = %+6.2f, %s; mejora en %2d de %d)\n', cfg.esc{c}, 100*mean(mej(:,c)), ...
            100*std(mej(:,c)), tc, ternario(abs(tc) > t_crit, 'significativo', 'no significativo'), sum(mej(:,c) > 0), size(mej,1));
end
tJ = (1 - mean(jr))/(std(jr)/sqrt(numel(jr)));
fprintf('  Jrel = %.4f ± %.4f  (t = %+.2f, %s)\n', mean(jr), std(jr), tJ, ternario(abs(tJ) > t_crit, 'SIGNIFICATIVO', 'no significativo'));
if abs(tJ) > t_crit && mean(jr) < 1 && all(okg)
    fprintf('-> Según la regla del grupo, el diseño LMI SUPERA a K0: corresponde revisar el diseño final.\n');
else
    fprintf('-> Según la regla del grupo, se mantiene K0 como diseño final.\n');
end

%% 5) Diagnóstico del fracaso de la región sigma >= 4
fprintf('\n=== 5) Diagnóstico del diseño LMI sigma >= 4 ===\n');
for c = {'C1', 'C2'}
    mi = metricas_qube(simular_qube(controlador_lineal(K_t), [], escenario_qube(c{1}), struct('ideal', true)));
    mr = metricas_qube(simular_qube(controlador_lineal(K_t), cfg.est, escenario_qube(c{1}), struct('semilla', 1)));
    diag5.(c{1}) = mi;
    fprintf('%s  ideal: éxito %d, max|u_c| = %7.1f V, saturado %5.1f %% | oficial: éxito %d, max|u_c| = %7.1f V, saturado %5.1f %%\n', ...
            c{1}, mi.exito, mi.max_uc, 100*mi.frac_sat, mr.exito, mr.max_uc, 100*mr.frac_sat);
end
fprintf('Ganancia por una cuenta del encoder en alpha: K0: %.2f V | LMI sigma>=4: %.2f V\n', ...
        abs(d.K0(2))*2*pi/2048, abs(K_t(2))*2*pi/2048);

%% Figura
figure('Color', 'w', 'Position', [60 60 1000 380]);
for b = 1:2
    subplot(1, 2, b);
    plot(res(b).v, res(b).Jcl, 'o--', res(b).v, res(b).Jl, 's-', res(b).v, res(b).Jq, '^-', 'LineWidth', 1.3); hold on;
    xline(ternario(b == 1, sb, zb), 'k:', 'diseño base');
    grid on; xlabel(ternario(b == 1, '\sigma_{min} [s^{-1}]  (\zeta_{min} = 0.5)', '\zeta_{min}  (\sigma_{min} = 0.458)'));
    ylabel('J_0 / J_{0,base}'); set(gca, 'YScale', 'log');
    legend('LMI: cota tr(Z)', 'LMI: costo real', 'mejor LQR de la malla', 'Location', 'northwest');
    title(ternario(b == 1, 'Costo de exigir decaimiento', 'Costo de exigir amortiguamiento'));
end
sgtitle('E1.5 (bonificación): región de polos por LMI frente a ajuste de Q');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_5_lmi.png'), 'Resolution', 200);
save(fullfile(raiz, 'resultados', 'E1_5_lmi.mat'), 'K_l', 'K_g', 'K_t', 'res', 'J0b', 'Jv0', 'Jvg', 'okg', 'mej', 'jr', 'tJ');
fprintf('\nGuardado: resultados/E1_5_lmi.mat y figuras/E1_5_lmi.png\n');

% Números citados en el informe: anotar -> results.json -> informe/valores_E1.tex
anotar('e15d_K_lmi_vs_K0', erel(K_l, d.K0), 'e1'); anotar('e15d_J_lmi_libre', J0f(K_l)/J0b, 'f6');
anotar('e15d_costo_region', J0f(K_g)/J0b - 1, 'p1');
anotar('e15d_sigma_g', sg_g, 'f3'); anotar('e15d_zeta_g', zt_g, 'f3');
anotar('e15d_base_sigma', sb, 'f3'); anotar('e15d_base_zeta', zb, 'f3');
i4 = find(abs(res(1).v - 4) < 1e-9); i6 = find(abs(res(1).v - 6) < 1e-9);
z85 = find(abs(res(2).v - 0.85) < 1e-9); z90 = find(abs(res(2).v - 0.9) < 1e-9);
anotar('e15d_s4_Q', res(1).Jq(i4), 'f2'); anotar('e15d_s4_LMI', res(1).Jl(i4), 'f2');
anotar('e15d_s6_Q', res(1).Jq(i6), 'f2'); anotar('e15d_s6_LMI', res(1).Jl(i6), 'f2');
anotar('e15d_z85_Q', res(2).Jq(z85), 'f2'); anotar('e15d_z85_LMI', res(2).Jl(z85), 'f2');
anotar('e15d_z90_Q', res(2).Jq(z90), 'f2'); anotar('e15d_z90_LMI', res(2).Jl(z90), 'f2');
okr = [res(1).ach(:,1) >= res(1).v(:) - 1e-6 & res(1).ach(:,2) >= cfg.zeta_min - 1e-6; ...
       res(2).ach(:,2) >= res(2).v(:) - 1e-6 & res(2).ach(:,1) >= cfg.sigma_min - 1e-6];
anotar('e15d_n_casos', numel(okr), 'd'); anotar('e15d_n_region_ok', sum(okr), 'd');
anotar('e15d_n_cota_ok', sum([res(1).Jcl(:) >= res(1).Jl(:); res(2).Jcl(:) >= res(2).Jl(:)]), 'd');
anotar('e15d_s4_C2_sat_ideal', diag5.C2.frac_sat, 'p1');
anotar('e15d_5sem_Jrel', jr5(2,1), 'f3'); anotar('e15d_5sem_desv', jr5(2,2), 'f3');
anotar('e15d_5sem_mejora', 1 - jr5(2,1), 'p1');
anotar('e15d_val_ok', sum(okg), 'd');
anotar('e15d_val_Jrel', mean(jr), 'f4'); anotar('e15d_val_Jrel_desv', std(jr), 'f4'); anotar('e15d_val_t', tJ, 'f2');
anotar('e15d_val_mej_C1', mean(mej(:,1)), 'p1'); anotar('e15d_val_mej_C2', mean(mej(:,2)), 'p1');
anotar('e15d_val_mej_C3b', mean(mej(:,4)), 'p1');

%% ======================= Funciones locales =======================
function [sigma, zeta] = sig_zeta(lam)
sigma = -max(real(lam)); c = lam(abs(imag(lam)) > 1e-9);
if isempty(c), zeta = 1; else, zeta = min(-real(c)./abs(c)); end
end

function [Jv, ms] = J_oficial(K, cfg, semilla)
ctrl = controlador_lineal(K); Jv = nan(1, numel(cfg.esc)); ms = cell(1, numel(cfg.esc));
for c = 1:numel(cfg.esc)
    ms{c} = metricas_qube(simular_qube(ctrl, cfg.est, escenario_qube(cfg.esc{c}), struct('semilla', semilla)));
    if ~isempty(ms{c}.J), Jv(c) = ms{c}.J; end
end
end

function s = ternario(c, a, b)
if c, s = a; else, s = b; end
end
