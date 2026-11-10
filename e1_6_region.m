%E1_6_REGION  Inciso E1.6: región de atracción del regulador saturado (diseño final K0).
%
%   (a) CERTIFICADO elipsoidal del régimen NO saturado del modelo LINEAL:
%       V(x) = x'Px con Acl'P + P Acl + Q0 + K'R0K = 0 (para K0, P es la de Riccati).
%       En E(rho) = {x'Px <= rho}:  max |Kx| = sqrt(rho K P^-1 K')  ->  rho* = Vmax^2/(K P^-1 K').
%       Dentro de E(rho*) no hay saturación, el lazo es lineal y dV/dt < 0: E(rho*) es invariante
%       y toda trayectoria que empieza dentro converge al origen.
%       Hipótesis: modelo lineal, tiempo continuo (sin retención de orden cero), estado completo
%       y exacto (sin estimador, ruido ni cuantización), sin límite de recorrido del brazo.
%   (b) ESTIMACIÓN empírica sobre la planta NO LINEAL saturada (lazo digital, estado real):
%       Monte Carlo 4D (20 000 condiciones iniciales uniformes en una caja declarada), tres cortes
%       2D (81 x 81) y búsqueda radial (bisección) en 4 ejes y 200 direcciones aleatorias.
%       Se usa src/simular_lote.m (vectorizado), verificado antes contra simular_qube.
%   Comprobaciones: rho* analítico frente a máximo numérico de |Kx| en la frontera; dV/dt < 0 en la
%   frontera también para el modelo NO lineal; ningún punto del elipsoide deja de recuperarse.
%   Evalúa la predicción E1-P1.

clear; clc; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
p = parametros_qube(); d = diseno_base_qube(); A = d.A; B = d.B;
K = diseno_final(); Vmax = p.Vmax;
Acl = A - B*K;
P = lyap_kron(Acl', d.Q0 + K'*d.R0*K); P = (P + P')/2;
semilla_mc = 2026; rng(semilla_mc, 'twister');

%% ===================== (a) Certificado elipsoidal =====================
rho = Vmax^2 / (K/P*K');
Pi = inv(P);
semi = sqrt(rho*diag(Pi))';                    % extensión máxima del elipsoide en cada eje (proyección)
corte = sqrt(rho./diag(P))';                   % extensión sobre cada eje (con los demás estados en 0)
fprintf('=== (a) Certificado elipsoidal (modelo lineal, sin saturación) ===\n');
fprintf('rho* = Vmax^2/(K P^-1 K'') = %.4e\n', rho);
fprintf('Sobre cada eje (resto en 0):  theta %.4f rad | alpha %.4f rad | dtheta %.4f rad/s | dalpha %.4f rad/s\n', corte);
fprintf('Proyección máxima por eje:    theta %.4f rad | alpha %.4f rad | dtheta %.4f rad/s | dalpha %.4f rad/s\n', semi);
fprintf('Cota de franja sobre alpha: Vmax/|K2| = %.4f rad (el corte del elipsoide debe ser <= esto)\n', Vmax/abs(K(2)));
% Comprobación 1: máximo numérico de |Kx| en la frontera
L = chol(P, 'lower');                          % P = L L'  ->  x = sqrt(rho) L'^-1 z, |z| = 1
Z = randn(4, 1e5); Z = Z./vecnorm(Z);
Xb = sqrt(rho) * (L' \ Z);
fprintf('Comprobación: máx |Kx| en 1e5 puntos de la frontera = %.6f V (debe ser <= %.0f y cercano)\n', max(abs(K*Xb)), Vmax);
% Comprobación 2: dV/dt < 0 en la frontera, modelo lineal y NO lineal (u = -Kx, sin saturar)
dVlin = 2*sum(Xb.*(P*(Acl*Xb)), 1);
fnl = dinamica_nl(Xb, -K*Xb, p);
dVnl = 2*sum(Xb.*(P*fnl), 1);
fprintf('dV/dt en la frontera: lineal máx %.3e (debe ser < 0) | NO lineal máx %.3e, negativo en %.2f %% de los puntos\n', ...
        max(dVlin), max(dVnl), 100*mean(dVnl < 0));
fprintf('Autovalores de Acl''P + P Acl = -(Q0 + K''R0K): %s\n', mat2str(eig(Acl'*P + P*Acl).', 3));
fprintf(['  -> semidefinida negativa: Q0 no pesa las velocidades y un autovalor es ~0, así que dV/dt <= 0\n' ...
         '     (no < 0). La convergencia se obtiene por LaSalle si (A, Q0^1/2) es observable.\n']);
Qh = diag(sqrt(diag(d.Q0))); Ob = [];
for i = 0:3, Ob = [Ob; Qh*A^i]; end %#ok<AGROW>
fprintf('  rango de la matriz de observabilidad de (A, Q0^1/2): %d de 4\n', rank(Ob));
% Comprobación 3: 5000 puntos uniformes DENTRO del elipsoide, en la planta no lineal con lazo digital
Zi = randn(4, 5000); Zi = Zi./vecnorm(Zi) .* rand(1, 5000).^(1/4);
Xi = sqrt(rho) * (L' \ Zi);
Ri = simular_lote(K, Xi, p);
fprintf(['Dentro del elipsoide (5000 puntos, planta no lineal, retención de orden cero): recuperados %d de 5000;\n' ...
         '  max|u_c| = %.3f V; puntos con alguna muestra saturada: %d\n\n'], sum(Ri.recuperado), max(Ri.max_uc), sum(Ri.max_uc > Vmax));

%% ===================== Verificación del simulador por lotes =====================
fprintf('=== Verificación de simular_lote frente a simular_qube (ideal) ===\n');
caja = [pi/2, 0.8, 10, 10];                     % semiancho de la caja de muestreo 4D (declarado)
Xv = (2*rand(4, 60) - 1) .* caja';
Rv = simular_lote(K, Xv, p);
dmax = 0; coinc = 0;
for i = 1:size(Xv, 2)
    esc = escenario_qube('C1'); esc.x0 = Xv(:,i); esc.nombre = 'MC';
    Lg = simular_qube(controlador_lineal(K), [], esc, struct('ideal', true));
    m = metricas_qube(Lg);
    al = atan2(sin(Lg.x(end,2)), cos(Lg.x(end,2)));
    rec = all(isfinite(Lg.x(end,:))) && abs(al) < 0.02 && abs(Lg.x(end,4)) < 0.2;
    coinc = coinc + (rec == Rv.recuperado(i) && m.exito == Rv.exito(i));
    if rec, dmax = max(dmax, norm(Lg.x(end,:)' - Rv.xf(:,i))); end
end
fprintf('Clasificación coincidente en %d de %d condiciones; máx. diferencia del estado final (recuperadas): %.1e\n\n', ...
        coinc, size(Xv, 2), dmax);

%% ===================== (b) Monte Carlo 4D =====================
N4 = 20000;
X4 = (2*rand(4, N4) - 1) .* caja';
tic; R4 = simular_lote(K, X4, p); t4 = toc;
dentro = sum(X4.*(P*X4), 1) <= rho;
fprintf('=== (b) Monte Carlo 4D: %d condiciones uniformes en la caja |x| <= %s (%.0f s) ===\n', N4, mat2str(caja, 3), t4);
fprintf('Recuperadas: %.2f %% | recuperadas sin exceder |theta| <= pi/2: %.2f %%\n', 100*mean(R4.recuperado), 100*mean(R4.exito));
fprintf('Dentro del elipsoide certificado: %d puntos (%.4f %% de la caja); recuperados de ellos: %d (deben ser todos)\n', ...
        sum(dentro), 100*mean(dentro), sum(R4.recuperado(dentro)));
fprintf('Volumen estimado de la región / volumen del elipsoide: %.0f\n', ...
        mean(R4.recuperado)*prod(2*caja) / (pi^2/2*rho^2/sqrt(det(P))));

%% ===================== Búsqueda radial =====================
D = [eye(4), -eye(4), randn(4, 200)];
D = D ./ vecnorm(D ./ caja');                   % dirección con norma 1 en coordenadas normalizadas por la caja
lo = zeros(1, size(D,2)); hi = 3*ones(1, size(D,2));   % hasta 3 veces la caja
Rh = simular_lote(K, D.*hi, p); cens = Rh.recuperado;  % si se recupera en hi, el radio es >= hi
for it = 1:18
    mid = (lo + hi)/2;
    Rm = simular_lote(K, D.*mid, p);
    lo(Rm.recuperado) = mid(Rm.recuperado); hi(~Rm.recuperado) = mid(~Rm.recuperado);
end
s_emp = lo; s_emp(cens) = 3;
s_cert = sqrt(rho ./ sum(D.*(P*D), 1));
razon = s_emp ./ s_cert;
fprintf('\n=== Búsqueda radial (bisección, 18 iteraciones) ===\n');
nomx = {'+theta', '+alpha', '+dtheta', '+dalpha', '-theta', '-alpha', '-dtheta', '-dalpha'};
for i = 1:8
    v = D(:,i); [~, j] = max(abs(v));
    fprintf('  %-8s radio estimado %8.4f | certificado %8.4f | razón %7.1f%s\n', nomx{i}, s_emp(i)*abs(v(j)), ...
            s_cert(i)*abs(v(j)), razon(i), ternario(cens(i), '  (>= 3 cajas)', ''));
end
fprintf('200 direcciones aleatorias: razón estimado/certificado mediana %.1f (mín %.1f, máx %.1f)\n', ...
        median(razon(9:end)), min(razon(9:end)), max(razon(9:end)));
al_emp = min(s_emp(2), s_emp(6)) * abs(D(2,2)); al_cert = corte(2);

%% ===================== Cortes 2D =====================
cortes = {[2 4], [1 2], [3 4]};
rng_c = {[0.8 10], [pi/2 0.8], [10 10]};
nomc = {'(alpha, dalpha)', '(theta, alpha)', '(dtheta, dalpha)'};
etq = {'\theta [rad]', '\alpha [rad]', 'd\theta/dt [rad/s]', 'd\alpha/dt [rad/s]'};
ng = 81; frac_corte = zeros(1, 3); frac_corte_ex = zeros(1, 3); G = cell(1,3);
fprintf('\n=== Cortes 2D (%d x %d, demás estados en 0) ===\n', ng, ng);
for c = 1:3
    ij = cortes{c}; g1 = linspace(-rng_c{c}(1), rng_c{c}(1), ng); g2 = linspace(-rng_c{c}(2), rng_c{c}(2), ng);
    [G1, G2] = meshgrid(g1, g2);
    Xc = zeros(4, ng^2); Xc(ij(1),:) = G1(:)'; Xc(ij(2),:) = G2(:)';
    Rc = simular_lote(K, Xc, p);
    frac_corte(c) = mean(Rc.recuperado); frac_corte_ex(c) = mean(Rc.exito);
    G{c} = struct('g1', g1, 'g2', g2, 'rec', reshape(Rc.recuperado, ng, ng), 'ex', reshape(Rc.exito, ng, ng), 'ij', ij);
    fprintf('  %-17s recuperadas %.2f %% | sin exceder pi/2: %.2f %%  (rectángulo %s)\n', nomc{c}, ...
            100*frac_corte(c), 100*frac_corte_ex(c), mat2str(rng_c{c}, 3));
end

%% ===================== Radio sobre el eje alpha: definiciones y simuladores =====================
%   recuperado: al final |alpha| < 0.02 rad y |dalpha| < 0.2 rad/s;  éxito: además |theta| <= pi/2.
%   Bisección sobre alpha0 (resto en 0) con el simulador por lotes (ideal) y con el kit OFICIAL
%   (estimador, cuantización, ruido), en este último el peor caso de 5 semillas.
fprintf('\n=== Radio sobre el eje alpha (bisección, 14 iteraciones) ===\n');
est = estimador_base(d);
rad = struct();
for def = {'recuperado', 'exito'}
    lo = 0; hi = 0.8;                                         % ideal (simular_lote)
    for it = 1:14
        mid = (lo + hi)/2; Rq = simular_lote(K, [0; mid; 0; 0], p);
        if Rq.(def{1}), lo = mid; else, hi = mid; end
    end
    rad.(['ideal_' def{1}]) = lo;
    lo = 0; hi = 0.8;                                         % oficial (kit), las 5 semillas deben cumplir
    for it = 1:14
        mid = (lo + hi)/2; ok = true;
        for s = 1:5
            esc = escenario_qube('C2'); esc.x0 = [0; mid; 0; 0]; esc.nombre = 'eje';
            Lg = simular_qube(controlador_lineal(K), est, esc, struct('semilla', s));
            al = atan2(sin(Lg.x(end,2)), cos(Lg.x(end,2)));
            rec = abs(al) < 0.02 && abs(Lg.x(end,4)) < 0.2;
            if strcmp(def{1}, 'exito'), rec = rec && max(abs(Lg.x(:,1))) <= p.theta_max; end
            ok = ok && rec;
            if ~ok, break; end
        end
        if ok, lo = mid; else, hi = mid; end
    end
    rad.(['oficial_' def{1}]) = lo;
end
fprintf('                       ideal (estado real)    oficial (estimador, cuantización, ruido; 5 semillas)\n');
fprintf('  recuperado           %8.4f rad          %8.4f rad\n', rad.ideal_recuperado, rad.oficial_recuperado);
fprintf('  éxito (|theta|<=pi/2) %8.4f rad          %8.4f rad\n', rad.ideal_exito, rad.oficial_exito);
fprintf('  certificado          %8.4f rad\n', al_cert);
fprintf('  Efecto del sensor sobre el radio (éxito): %.1f %%\n', 100*(rad.oficial_exito/rad.ideal_exito - 1));
fprintf('  C2 (alpha0 = 0.35 rad) queda %s del radio oficial de éxito.\n', ternario(0.35 <= rad.oficial_exito, 'DENTRO', 'FUERA'));

%% ===================== Predicción E1-P1 =====================
fprintf('\n=== Predicción E1-P1 ===\n');
fprintf('Certificado sobre alpha: %.4f rad (predicho: <= 0.055) -> %s\n', al_cert, ternario(al_cert <= 0.055, 'cumple', 'no cumple'));
fprintf('Estimado sobre alpha:    %.4f rad ideal, %.4f rad oficial con éxito (predicho: >= 5 x 0.055 = 0.27) -> %s\n', ...
        al_emp, rad.oficial_exito, ternario(min(al_emp, rad.oficial_exito) >= 0.27, 'cumple', 'no cumple'));

%% Figuras
figure('Color', 'w', 'Position', [40 60 1300 420]);
for c = 1:3
    subplot(1, 3, c); ij = G{c}.ij;
    img = 1*G{c}.ex + 0.5*(G{c}.rec & ~G{c}.ex);
    imagesc(G{c}.g1, G{c}.g2, img); set(gca, 'YDir', 'normal'); colormap(gca, [0.85 0.33 0.1; 0.93 0.69 0.13; 0.3 0.6 0.9]);
    clim([0 1]); hold on;
    Pij = P(ij, ij); t = linspace(0, 2*pi, 200); Lc = chol(Pij, 'lower');
    E = sqrt(rho) * (Lc' \ [cos(t); sin(t)]);
    plot(E(1,:), E(2,:), 'k-', 'LineWidth', 2);
    xlabel(etq{ij(1)}); ylabel(etq{ij(2)}); title(['Corte ' nomc{c}]); axis tight;
end
sgtitle('E1.6: azul = recuperado; amarillo = recuperado excediendo |\theta|>\pi/2; rojo = no recuperado; negro = certificado');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_6_cortes.png'), 'Resolution', 200);

figure('Color', 'w', 'Position', [60 520 560 360]);
histogram(log10(razon(9:end)), 25); grid on;
xlabel('log_{10}(radio estimado / radio certificado)'); ylabel('direcciones');
title('E1.6: cuánto subestima el certificado (200 direcciones)');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_6_razon.png'), 'Resolution', 200);

mc_region = struct('corte_alpha_dalpha', frac_corte(1), 'corte_theta_alpha', frac_corte(2), ...
                   'corte_dtheta_dalpha', frac_corte(3), 'mc_4d', mean(R4.recuperado), 'n_4d', N4, ...
                   'caja_4d', caja, 'semilla', semilla_mc);
save(fullfile(raiz, 'resultados', 'E1_6.mat'), 'rho', 'P', 'K', 'corte', 'semi', 'mc_region', 'frac_corte_ex', 'rad', 'Ri', ...
     'R4', 'X4', 's_emp', 's_cert', 'razon', 'D', 'G', 'al_emp', 'al_cert');
fprintf('\nGuardado: resultados/E1_6.mat, figuras/E1_6_cortes.png, figuras/E1_6_razon.png\n');

% Números citados en el informe: anotar -> results.json -> informe/valores_E1.tex
anotar('e16_rho', rho, 'e3');
anotar('e16_corte_theta', corte(1), 'f3'); anotar('e16_corte_alpha', corte(2), 'f4');
anotar('e16_franja', Vmax/abs(K(2)), 'f3');
anotar('e16_al_emp', al_emp, 'f3');
anotar('e16_rad_ideal_exito', rad.ideal_exito, 'f3'); anotar('e16_rad_oficial_exito', rad.oficial_exito, 'f3');
anotar('e16_rad_oficial_rec', rad.oficial_recuperado, 'f3');
anotar('e16_efecto_sensor', rad.oficial_exito/rad.ideal_exito - 1, 'p1');
anotar('e16_P1_razon_id', al_emp/al_cert, 'f0'); anotar('e16_P1_razon_of', rad.oficial_exito/al_cert, 'f0');
anotar('e16_razon_min', min(razon(9:end)), 'f1'); anotar('e16_razon_max', max(razon(9:end)), 'f1');
anotar('e16_razon_med', median(razon(9:end)), 'f1'); anotar('e16_n_dir', numel(razon) - 8, 'd');
anotar('e16_mc_N', N4, 'd'); anotar('e16_mc_rec', mean(R4.recuperado), 'p1'); anotar('e16_mc_exito', mean(R4.exito), 'p1');
anotar('e16_C2_margen', rad.oficial_exito - 0.35, 'f3');
anotar('e16_max_Kx', max(abs(K*Xb)), 'f3');
anotar('e16_dV_neg', mean(dVnl < 0), 'p0'); anotar('e16_rango_obs', rank(Ob), 'd');
anotar('e16_in_rec', sum(Ri.recuperado), 'd'); anotar('e16_in_n', numel(Ri.recuperado), 'd');
anotar('e16_in_max_uc', max(Ri.max_uc), 'f3'); anotar('e16_in_sat', sum(Ri.max_uc > Vmax), 'd');
anotar('e16_lote_coinc', coinc, 'd'); anotar('e16_lote_n', size(Xv, 2), 'd'); anotar('e16_lote_dif', dmax, 'e1');
anotar('e16_vol_razon', mean(R4.recuperado)*prod(2*caja) / (pi^2/2*rho^2/sqrt(det(P))), 'f0');
anotar('e16_radio_theta', s_emp(1)*max(abs(D(:,1))), 'f1');

%% ======================= Funciones locales =======================
function dx = dinamica_nl(x, u, p)
w = x(3,:); ad = x(4,:); s = sin(x(2,:)); c = cos(x(2,:));
tau = p.kt*(u - p.km*w)/p.Rm;
f1 = tau - p.Dr*w - 2*p.Jp*s.*c.*w.*ad - p.mp*p.r*p.lp*s.*ad.^2;
f2 = p.mp*p.g*p.lp*s + p.Jp*s.*c.*w.^2 - p.Dp*ad;
M11 = p.Jr + p.mp*p.r^2 + p.Jp*s.^2; M12 = -p.mp*p.r*p.lp*c; M22 = p.Jp;
dt = M11*M22 - M12.^2;
dx = [w; ad; (M22*f1 - M12.*f2)./dt; (-M12.*f1 + M11.*f2)./dt];
end

function s = ternario(c, a, b)
if c, s = a; else, s = b; end
end
