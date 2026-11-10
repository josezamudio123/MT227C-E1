%E1_2_VERIFICACION  Inciso E1.2: verificación de cada solución de Riccati y
%   demostración de que un RESIDUO PEQUEÑO NO IMPLICA UN ERROR PEQUEÑO EN P.
%
%   Idea (primer orden): si P = P* + D, entonces
%       Res(P) = A'P + PA - PSP + Q = Ac' D + D Ac - D S D  ~  L(D),
%   con L(X) = Ac' X + X Ac el operador de Lyapunov del lazo cerrado (Ac = A - S P*).
%   Por lo tanto  ||D|| <~ ||L^-1|| * ||Res||.  Si ||L^-1|| es grande (autovalores de
%   Ac cerca del eje imaginario, porque los de L son lambda_i + lambda_j), un residuo
%   pequeño es compatible con un error grande.
%
%   Parte A: péndulo (diseño base): las cuatro verificaciones de cada método y la cota
%            de error ||L^-1||*||Res||/||P|| frente al error medido.
%   Parte B: caso construido (oscilador casi sin amortiguamiento) donde un error de 1 %
%            en P produce un residuo de hasta 1e-8.

clear; clc; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
erel = @(X, Y) norm(X - Y, 'fro') / norm(Y, 'fro');

%% ===================== PARTE A: péndulo, diseño base =====================
d = diseno_base_qube();
A = d.A; B = d.B; Q = d.Q0; R = d.R0; S = B/R*B';
Pref = icare(A, B, Q, R);
Ac = A - S*Pref;
[~, sepA, nLinvA] = operador_lyapunov(Ac);
fprintf('=== PARTE A: péndulo, diseño base ===\n');
fprintf('Polos de lazo cerrado: %s\n', mat2str(eig(Ac).', 4));
fprintf('sep(L) = sigma_min = %.3e   ||L^-1|| = %.3e\n\n', sepA, nLinvA);

sol = {riccati_hamiltoniano(A, B, Q, R), riccati_schur(A, B, Q, R), ...
       riccati_newton(A, B, Q, R, ganancia_bass(A, B, 20))};
nom = {'(a) Hamiltoniana', '(b) Schur', '(c) Newton-K.'};
fprintf('%-17s %10s %10s %10s %10s | %12s %12s\n', 'Método', 'residuo', 'asimetría', 'min eig P', ...
        'max Re cl', 'cota error', 'error real');
for m = 1:3
    P = sol{m};
    v = verificar_riccati(A, B, Q, R, P);
    Res = A'*P + P*A - P*S*P + Q;
    cota = nLinvA * norm(Res, 'fro') / norm(P, 'fro');      % ||D||/||P|| <~ ||L^-1|| ||Res|| / ||P||
    fprintf('%-17s %10.2e %10.2e %10.2e %10.3f | %12.2e %12.2e\n', nom{m}, v.residuo, v.asimetria, ...
            v.min_eig_P, v.max_re_cl, cota, erel(P, Pref));
end
fprintf(['\nEn el péndulo ||L^-1|| es moderado: la cota queda siempre POR ENCIMA del error real\n' ...
         '(es conservadora, 2 a 3 órdenes), pero es pequeña; aquí un residuo pequeño SÍ\n' ...
         'garantiza un error pequeño.\n\n']);

%% ===================== PARTE B: caso construido =====================
% Oscilador sin amortiguamiento, entrada débilmente ponderada:
%   A = [0 1; -1 0], B = [0; 1], R = 1, Q = eps^2 I
% Con eps -> 0 el LQR casi no amortigua: polos de lazo cerrado ~ -eps/sqrt(2) +- j,
% es decir, cerca del eje imaginario -> ||L^-1|| crece como 1/eps.
% Solución EXACTA (deducida a mano con P = [p1 p2; p2 p3]):
%   (1,1): -2 p2 - p2^2 + eps^2 = 0  ->  p2 = eps^2 / (1 + sqrt(1 + eps^2))  (forma sin cancelación)
%   (2,2):  2 p2 - p3^2 + eps^2 = 0  ->  p3 = sqrt(2 p2 + eps^2)
%   (1,2):  p1 - p3 - p2 p3 = 0      ->  p1 = p3 (1 + p2)
% Se usa la solución exacta como referencia (no icare), para que el residuo de la
% propia referencia no contamine la demostración.
fprintf('=== PARTE B: caso construido (oscilador casi sin amortiguamiento) ===\n');
fprintf('Se perturba P* con un error relativo FIJO de 1%% en dos direcciones:\n');
fprintf('  "peor"  : dirección del menor valor singular de L (la que L casi no ve)\n');
fprintf('  "azar"  : dirección simétrica aleatoria (semilla fija)\n\n');
Ao = [0 1; -1 0]; Bo = [0; 1]; Ro = 1; So = Bo/Ro*Bo';
epss = 10.^(-1:-1:-6);
eta = 1e-2;                                  % error relativo impuesto
rng(1, 'twister'); G = randn(2); G = (G + G')/2; G = G/norm(G, 'fro');
fprintf('%8s %12s %12s %12s %12s %12s %12s %12s\n', 'eps', 'Re(polo cl)', '||L^-1||', 'error P', ...
        'res. peor', 'res. azar', 'L(D) vs Res', 'icare vs ex.');
tab = zeros(numel(epss), 6);
for k = 1:numel(epss)
    e = epss(k); Qo = e^2*eye(2);
    p2 = e^2/(1 + sqrt(1 + e^2)); p3 = sqrt(2*p2 + e^2); p1 = p3*(1 + p2);
    Ps = [p1 p2; p2 p3];                                  % solución exacta
    e_icare = erel(icare(Ao, Bo, Qo, Ro), Ps);            % de paso: precisión de icare
    Aco = Ao - So*Ps;
    [Lop, ~, nLinv] = operador_lyapunov(Aco);
    [~, ~, V] = svd(Lop);
    D = reshape(V(:, end), 2, 2); D = (D + D')/2; D = D/norm(D, 'fro');   % dirección "peor" simétrica
    Pp = Ps + eta*norm(Ps, 'fro')*D;                                       % error relativo = eta
    Pr = Ps + eta*norm(Ps, 'fro')*G;
    r_peor = residuo_riccati(Ao, Bo, Qo, Ro, Pp);
    r_azar = residuo_riccati(Ao, Bo, Qo, Ro, Pr);
    % Comprobación del primer orden: Res(P*+D) ~ L(D)
    Dp = Pp - Ps;
    Res = Ao'*Pp + Pp*Ao - Pp*So*Pp + Qo;
    LD  = Aco'*Dp + Dp*Aco;
    fprintf('%8.0e %12.2e %12.2e %12.2e %12.2e %12.2e %12.2e %12.2e\n', e, max(real(eig(Aco))), nLinv, ...
            erel(Pp, Ps), r_peor, r_azar, norm(Res - LD, 'fro')/norm(Res, 'fro'), e_icare);
    tab(k, :) = [e, nLinv, r_peor, r_azar, erel(Pp, Ps), e_icare];
end
fprintf(['\nLectura: el error de P es SIEMPRE 1%%, pero en la dirección "peor" el residuo cae\n' ...
         'proporcional a eps (hasta ~1e-8), mientras ||L^-1|| crece como 1/eps.\n' ...
         'Un residuo de 1e-8 NO certifica 8 cifras correctas: aquí solo hay 2.\n' ...
         'En una dirección al azar el residuo sí refleja el error (~1e-2).\n']);

%% Figura
figure('Color', 'w', 'Position', [100 100 760 400]);
loglog(tab(:,1), tab(:,3), 'o-', 'LineWidth', 1.5); hold on;
loglog(tab(:,1), tab(:,4), 's-', 'LineWidth', 1.5);
loglog(tab(:,1), tab(:,5), 'k--', 'LineWidth', 1.2);
loglog(tab(:,1), 1./tab(:,2), '^-', 'LineWidth', 1.2);
set(gca, 'XDir', 'reverse'); grid on;
xlabel('\epsilon  (Q = \epsilon^2 I)   \rightarrow  polos de lazo cerrado más cerca del eje imaginario');
ylabel('magnitud');
legend('residuo, dirección peor', 'residuo, dirección al azar', 'error relativo de P (fijo, 1 %)', ...
       'sep(L) = 1/||L^{-1}||', 'Location', 'southwest');
title('E1.2: residuo pequeño no implica error pequeño');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_2_residuo_vs_error.png'), 'Resolution', 200);

save(fullfile(raiz, 'resultados', 'E1_2.mat'), 'tab', 'sepA', 'nLinvA');
fprintf('\nGuardado: resultados/E1_2.mat y figuras/E1_2_residuo_vs_error.png\n');
