%E1_4_PARETO  Inciso E1.4: frente de Pareto de tres objetivos cuadráticos.
%
%   Objetivos (valor esperado sobre la condición inicial, x0 ~ media 0, covarianza X0):
%     J_th = E int theta^2 dt     (brazo)
%     J_al = E int alpha^2 dt     (péndulo)
%     J_u  = E int u^2 dt         (esfuerzo),  u = -K x
%   Escalarización (normalización de Bryson con los mismos máximos que el diseño base):
%     Q = diag(r_th/(pi/4)^2, r_al/(pi/36)^2, 0, 0),  R = 1/10^2,
%     r_th, r_al en una malla logarítmica 25 x 25 de 1e-3 a 1e3  ->  625 diseños.
%     (r_th = r_al = 1 reproduce el diseño base Q0, R0.)
%   Evaluación por ecuaciones de Lyapunov, por DOS caminos:
%     primal: Acl W + W Acl' + X0 = 0,             J_i = tr(C_i W C_i')   (sylvester, MATLAB base)
%     dual  : Acl' P_i + P_i Acl + C_i' C_i = 0,   J_i = tr(P_i X0)       (lyap_kron, propio)
%   Comprobación con respuesta conocida: la suma ponderada de los objetivos debe ser
%   tr(P_LQR X0), y todo diseño LQR con pesos positivos es no dominado.
%   Verificación por simulación: (a) lineal con ode45 para 10 diseños; (b) NO LINEAL en el
%   simulador del kit para los 625: C1 y C2 ideales (estado real, sin ruido) y C2 REAL
%   (estimador base, encoders cuantizados, ruido de par, semilla 1): max|u_c|, max|theta|.
%   Las simulaciones no lineales se guardan en caché (resultados/E1_4_sim.mat).

clear; clc; close all;
recalcular_sim = isappdata(0, 'E1_regenerar') && getappdata(0, 'E1_regenerar');
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
d = diseno_base_qube(); p = parametros_qube();
A = d.A; B = d.B; n = 4;

%% Covarianza inicial declarada (supuesto)
%   sigma_th = 0.1 rad, sigma_al = 0.05 rad (amplitud de C1),
%   sigma_dth = sigma_dal = 0.5 rad/s (orden de los saltos de velocidad de un impulso como C3).
sig = [0.1 0.05 0.5 0.5];
X0 = diag(sig.^2);
fprintf('X0 = diag(%s)\n', mat2str(sig.^2, 3));

%% Malla de pesos
r = 10.^linspace(-3, 3, 25);
[RTH, RAL] = meshgrid(r, r); RTH = RTH(:); RAL = RAL(:);
N = numel(RTH);
Ct = [1 0 0 0]; Ca = [0 1 0 0];
nrm = [(pi/4)^2, (pi/36)^2, 10^2];            % normalización de Bryson (th, al, u)
J = zeros(N, 3); Jd = zeros(N, 3); Jlqr = zeros(N, 1); K = zeros(N, 4);
dif_solver = zeros(N, 1); maxre = zeros(N, 1);
for k = 1:N
    Q = diag([RTH(k)/nrm(1), RAL(k)/nrm(2), 0, 0]); R = 1/nrm(3);
    P = icare(A, B, Q, R);                                  % solucionador principal (E1.3)
    dif_solver(k) = norm(P - riccati_hamiltoniano(A, B, Q, R), 'fro')/norm(P, 'fro');
    K(k, :) = R \ (B'*P);
    Acl = A - B*K(k, :);
    maxre(k) = max(real(eig(Acl)));
    % Camino primal (sylvester de MATLAB base, algoritmo de Bartels-Stewart): gramiano W
    W = sylvester(Acl, Acl', -X0);
    J(k, :) = [Ct*W*Ct', Ca*W*Ca', K(k,:)*W*K(k,:)'];
    % Camino dual (lyap_kron propio): una ecuación por objetivo
    Cs = {Ct, Ca, K(k,:)};
    for i = 1:3
        Pi = lyap_kron(Acl', Cs{i}'*Cs{i});
        Jd(k, i) = trace(Pi*X0);
    end
    Jlqr(k) = trace(P*X0);                                  % costo LQR esperado
end
Jn = J ./ nrm;                                              % objetivos normalizados
ib = find(abs(RTH - 1) < 1e-12 & abs(RAL - 1) < 1e-12);     % diseño base

%% Comprobaciones
e_dual = max(max(abs(J - Jd) ./ abs(J)));
suma = RTH.*Jn(:,1) + RAL.*Jn(:,2) + Jn(:,3);               % sum w_i J_i normalizados
e_suma = max(abs(suma - Jlqr) ./ Jlqr);
nd = no_dominados(Jn);
fprintf('\n=== Comprobaciones (%d diseños) ===\n', N);
fprintf('Todos estables: %d de %d (max Re = %.3f)\n', sum(maxre < 0), N, max(maxre));
fprintf('icare vs Hamiltoniana (eig balanceada): máx. diferencia relativa %.1e\n', max(dif_solver));
fprintf('Lyapunov primal (sylvester) vs dual (lyap_kron): máx. diferencia relativa %.1e\n', e_dual);
fprintf('Suma ponderada de objetivos vs tr(P X0): máx. diferencia relativa %.1e\n', e_suma);
fprintf('No dominados: %d de %d (teoría: todos, por ser LQR con pesos positivos)\n', sum(nd), N);
fprintf('Diseño base: K = %s  (K0 del kit: %s)\n', mat2str(K(ib,:), 5), mat2str(d.K0, 5));
fprintf('Rango de los objetivos normalizados:\n');
fprintf('  J_th/(pi/4)^2  : %.2e a %.2e\n', min(Jn(:,1)), max(Jn(:,1)));
fprintf('  J_al/(pi/36)^2 : %.2e a %.2e\n', min(Jn(:,2)), max(Jn(:,2)));
fprintf('  J_u/10^2       : %.2e a %.2e\n', min(Jn(:,3)), max(Jn(:,3)));

%% (a) Simulación lineal con ode45 (10 diseños): E[int x'Mx] = sum_i J(x0 = sigma_i e_i)
idx = round(linspace(1, N, 10)); idx(5) = ib;
fprintf('\n=== Lyapunov vs simulación lineal (ode45, 10 diseños) ===\n');
fprintf('%6s %8s %8s | %10s %10s %10s\n', 'diseño', 'r_th', 'r_al', 'err J_th', 'err J_al', 'err J_u');
e_sim = zeros(numel(idx), 3);
opt = odeset('RelTol', 1e-10, 'AbsTol', 1e-14);
for m = 1:numel(idx)
    k = idx(m); Acl = A - B*K(k,:);
    tf = 40/min(abs(real(eig(Acl))));                       % 40 constantes de tiempo
    Js = zeros(1, 3);
    for i = 1:4
        if sig(i) == 0, continue; end
        z0 = [sig(i)*((1:4)' == i); 0; 0; 0];               % estado + 3 integrales de costo
        f = @(t, z) [Acl*z(1:4); z(1)^2; z(2)^2; (K(k,:)*z(1:4))^2];
        [~, Z] = ode45(f, [0 tf], z0, opt);
        Js = Js + Z(end, 5:7);
    end
    e_sim(m, :) = abs(Js - J(k,:)) ./ J(k,:);
    fprintf('%6d %8.1e %8.1e | %10.1e %10.1e %10.1e\n', k, RTH(k), RAL(k), e_sim(m,:));
end

%% (b) Simulación NO LINEAL en el kit
%   columna 1: C1 ideal | columna 2: C2 ideal | columna 3: C2 real (estimador + cuantización + ruido)
archivo_sim = fullfile(raiz, 'resultados', 'E1_4_sim.mat');
usar_cache = ~recalcular_sim && isfile(archivo_sim);
if usar_cache
    load(archivo_sim, 'NL');
    usar_cache = size(NL.max_uc, 2) == 3;               % caché de una versión anterior -> recalcular
end
if usar_cache
    fprintf('\nSimulaciones no lineales cargadas de la caché.\n');
else
    fprintf('\nSimulando %d diseños x 3 casos en el kit (puede tardar varios minutos)...\n', N);
    NL = struct('max_uc', zeros(N,3), 'max_th', zeros(N,3), 'frac_sat', zeros(N,3), 'exito', false(N,3));
    escs = {escenario_qube('C1'), escenario_qube('C2'), escenario_qube('C2')};
    opcs = {struct('ideal', true), struct('ideal', true), struct('ideal', false, 'semilla', 1)};
    est = estimador_base(d);
    tic;
    for k = 1:N
        ctrl = controlador_lineal(K(k,:));
        for c = 1:3
            L = simular_qube(ctrl, est, escs{c}, opcs{c});
            mm = metricas_qube(L);
            NL.max_uc(k,c) = mm.max_uc; NL.max_th(k,c) = mm.max_theta;
            NL.frac_sat(k,c) = mm.frac_sat; NL.exito(k,c) = mm.exito;
        end
        if mod(k, 50) == 0, fprintf('  %d/%d (%.0f s)\n', k, N, toc); end
    end
    save(archivo_sim, 'NL');
end
fprintf('\n=== Verificación no lineal en el kit ===\n');
fprintf('Diseño base, ideal: C1 max|u_c| = %.2f V (ref. 9.12), C2 max|theta| = %.3f rad (ref. 1.237)\n', ...
        NL.max_uc(ib,1), NL.max_th(ib,2));
fprintf('Diseño base, C2 real: max|u_c| = %.2f V (pruebas_kit: 63.82), max|theta| = %.3f rad (1.345)\n', ...
        NL.max_uc(ib,3), NL.max_th(ib,3));
fprintf('Éxito: C1 ideal %d | C2 ideal %d | C2 real %d   (de %d)\n', sum(NL.exito), N);
okC2i = NL.exito(:,2) & NL.frac_sat(:,2) <= 0.05;
okC2r = NL.exito(:,3) & NL.frac_sat(:,3) <= 0.05;
fprintf('C2 con |theta| <= pi/2 y saturación <= 5 %%: ideal %d | real %d   (de %d)\n', sum(okC2i), sum(okC2r), N);
fprintf('Diseños con éxito en C2 ideal que FALLAN en C2 real (efecto del sensor): %d\n', ...
        sum(NL.exito(:,2) & ~NL.exito(:,3)));
fprintf('Diseños que fallan en ideal y tienen éxito en real: %d\n', sum(~NL.exito(:,2) & NL.exito(:,3)));
rho = spearman(Jn(:,3), NL.max_uc(:,1));
fprintf('Correlación de rangos (Spearman) entre J_u (Lyapunov) y max|u_c| en C1 ideal: %.3f\n', rho);

%% Figuras
figure('Color', 'w', 'Position', [60 60 620 500]);
g1 = NL.exito(:,2) & NL.exito(:,3); g2 = NL.exito(:,2) & ~NL.exito(:,3); g3 = ~NL.exito(:,2);
scatter3(Jn(g3,1), Jn(g3,2), Jn(g3,3), 14, [0.85 0.33 0.1], 'filled'); hold on;
scatter3(Jn(g2,1), Jn(g2,2), Jn(g2,3), 14, [0.93 0.69 0.13], 'filled');
scatter3(Jn(g1,1), Jn(g1,2), Jn(g1,3), 14, [0 0.45 0.74], 'filled');
scatter3(Jn(ib,1), Jn(ib,2), Jn(ib,3), 120, 'k', 'p', 'filled');
set(gca, 'XScale', 'log', 'YScale', 'log', 'ZScale', 'log'); grid on; view(135, 25);
xlabel('J_\theta/(\pi/4)^2'); ylabel('J_\alpha/(\pi/36)^2'); zlabel('J_u/10^2');
legend('falla C2 ideal', 'éxito ideal, falla real', 'éxito C2 ideal y real', 'diseño base', 'Location', 'northeast');
title(sprintf('E1.4: frente de Pareto (%d diseños LQR)', N));
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_4_pareto3d.png'), 'Resolution', 200);

figure('Color', 'w', 'Position', [700 60 1100 400]);
subplot(1, 2, 1);
scatter(Jn(:,3), Jn(:,2), 16, log10(Jn(:,1)), 'filled'); hold on;
plot(Jn(ib,3), Jn(ib,2), 'kp', 'MarkerSize', 12, 'MarkerFaceColor', 'k');
set(gca, 'XScale', 'log', 'YScale', 'log'); grid on; cb = colorbar; cb.Label.String = 'log_{10} J_\theta/(\pi/4)^2';
xlabel('esfuerzo  J_u/10^2'); ylabel('péndulo  J_\alpha/(\pi/36)^2'); title('Proyección esfuerzo-péndulo');
subplot(1, 2, 2);
loglog(Jn(:,3), NL.max_uc(:,1), '.', 'MarkerSize', 8); hold on;
loglog(Jn(:,3), NL.max_uc(:,2), '.', 'MarkerSize', 8);
loglog(Jn(:,3), NL.max_uc(:,3), '.', 'MarkerSize', 8);
plot(Jn(ib,3)*[1 1 1], NL.max_uc(ib,:), 'kp', 'MarkerFaceColor', 'k');
yline(p.Vmax, 'r--', 'V_{max} = 10 V'); grid on;
xlabel('J_u/10^2 (Lyapunov)'); ylabel('max |u_c| [V] (no lineal)'); legend('C1 ideal', 'C2 ideal', 'C2 real', 'base', 'Location', 'northwest');
title('Lyapunov frente a simulación no lineal');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_4_proyecciones.png'), 'Resolution', 200);

save(fullfile(raiz, 'resultados', 'E1_4.mat'), 'RTH', 'RAL', 'K', 'J', 'Jn', 'Jlqr', 'X0', 'NL', 'ib', ...
     'e_dual', 'e_suma', 'e_sim', 'dif_solver', 'nd');
fprintf('\nGuardado: resultados/E1_4.mat, figuras/E1_4_pareto3d.png, figuras/E1_4_proyecciones.png\n');

function rho = spearman(x, y)
% Correlación de rangos de Spearman sin Statistics Toolbox (sin empates relevantes).
rx = zeros(size(x)); ry = rx;
[~, ix] = sort(x); rx(ix) = 1:numel(x);
[~, iy] = sort(y); ry(iy) = 1:numel(y);
c = corrcoef(rx, ry); rho = c(1, 2);
end

function nd = no_dominados(F)
% Filtro de Pareto (minimización): i es dominado si existe j con F(j,:) <= F(i,:) en
% todo y < en alguno.
N = size(F, 1); nd = true(N, 1);
for i = 1:N
    dom = all(F <= F(i,:), 2) & any(F < F(i,:), 2);
    nd(i) = ~any(dom);
end
end
