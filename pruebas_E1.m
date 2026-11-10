%PRUEBAS_E1  Pruebas con respuesta conocida del encargo E1 (hito H1).
%
%   Prueba 1 (caso escalar, guía sección 3.1):
%     xdot = x + u, Q = q > 0, R = 1  ->  K = 1 + sqrt(1 + q)
%     margen de fase > 60 grados, tiende a 60 por encima cuando q -> 0
%     (65.5 grados para q = 1); ganancia mínima tolerable -> 1/2.
%   Prueba 2 (péndulo, diseño base):
%     los tres solucionadores (Hamiltoniana, Schur, Newton-Kleinman) coinciden
%     entre sí, con care/icare de biblioteca y con P0 del kit: diferencia < 1e-10.

clear; clc;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
erel = @(X, Y) norm(X - Y, 'fro') / norm(Y, 'fro');
tol = 1e-10;
todo_ok = true;

%% ===================== PRUEBA 1: caso escalar =====================
fprintf('=== PRUEBA 1: xdot = x + u, Q = q, R = 1 ===\n\n');
fprintf('%9s %10s %10s %10s %10s %9s %9s %8s %8s\n', 'q', 'K exacta', 'err Ham.', 'err Schur', 'err Newt.', ...
        'MF [deg]', 'MF num.', 'g_min', '');
qs = [1 0.1 1e-2 1e-4 1e-6];
mf_ant = Inf; ok1 = true;
for q = qs
    Kex = 1 + sqrt(1 + q);                              % solución analítica
    Pa = riccati_hamiltoniano(1, 1, q, 1);
    Pb = riccati_schur(1, 1, q, 1);
    Pc = riccati_newton(1, 1, q, 1, 2);                 % K_ini = 2 estabiliza (1 - 2 < 0)
    ea = abs(Pa - Kex)/Kex; eb = abs(Pb - Kex)/Kex; ec = abs(Pc - Kex)/Kex;   % K = P porque B = R = 1
    % Margen de fase: L(s) = K/(s - 1); |L(jw)| = 1 -> wc = sqrt(K^2 - 1)
    wc = sqrt(Kex^2 - 1);
    MF = 180 + rad2deg(angle(Kex/(1j*wc - 1)));         % analítico: atan(wc)
    % Segundo camino: cruce de ganancia hallado numéricamente con fzero
    wc_num = fzero(@(w) abs(Kex/(1j*w - 1)) - 1, [1e-3, 1e3]);
    MF_num = 180 + rad2deg(angle(Kex/(1j*wc_num - 1)));
    gmin = 1/Kex;                                       % lazo cerrado: s - 1 + g K = 0 estable si g > 1/K
    ok = max([ea eb ec]) < tol && MF > 60 && MF < mf_ant && abs(MF - MF_num) < 1e-6;
    ok1 = ok1 && ok; mf_ant = MF;
    fprintf('%9.0e %10.6f %10.1e %10.1e %10.1e %9.4f %9.4f %8.5f %8s\n', q, Kex, ea, eb, ec, MF, MF_num, gmin, marca(ok));
end
% Valor puntual de la guía: 65.5 grados para q = 1
MF1 = rad2deg(atan(sqrt((1 + sqrt(2))^2 - 1)));
ok_655 = abs(MF1 - 65.5) < 0.05;
fprintf('\nq = 1: MF = %.2f grados (guía: 65.5)  -> %s\n', MF1, marca(ok_655));
fprintf('q -> 0: MF -> %.4f grados (debe tender a 60 por encima), g_min -> %.5f (debe tender a 0.5)\n', MF, gmin);
% Tercer camino (si hay Control System Toolbox): margin
% margin/allmargin hallan la frecuencia de cruce NUMÉRICAMENTE, con su propio error
% (del orden de 1e-3 grados); por eso la tolerancia frente al valor exacto es 0.01 grados.
try
    L1 = tf(1 + sqrt(2), [1 -1]);
    [Gm, Pm] = margin(L1);
    Sm = allmargin(L1);
    fprintf('Control System Toolbox, margin():    MF = %.4f grados (dif. %.1e), margen de ganancia = %.4f (1/K = %.4f)\n', ...
            Pm, abs(Pm - MF1), Gm, 1/(1 + sqrt(2)));
    fprintf('Control System Toolbox, allmargin(): MF = %.4f grados (dif. %.1e), margen de ganancia = %.4f\n', ...
            Sm.PhaseMargin(1), abs(Sm.PhaseMargin(1) - MF1), Sm.GainMargin(1));
    ok_655 = ok_655 && abs(Pm - MF1) < 1e-2 && abs(Gm - 1/(1 + sqrt(2))) < 1e-3;
catch
    fprintf('(margin no disponible: se omite el tercer camino)\n');
end
ok1 = ok1 && ok_655;
todo_ok = todo_ok && ok1;
fprintf('PRUEBA 1: %s\n\n', marca(ok1));

%% ===================== PRUEBA 2: péndulo, diseño base =====================
fprintf('=== PRUEBA 2: péndulo de Furuta, diseño base (Q0, R0) ===\n\n');
d = diseno_base_qube();
A = d.A; B = d.B; Q = d.Q0; R = d.R0;

% Ganancia inicial estabilizante para Newton-Kleinman (declarada en el informe):
beta = 20;                     % > 17.63 = max(-real(eig(A)))
K_ini = ganancia_bass(A, B, beta);
fprintf('Ganancia inicial (Bass, beta = %g): K_ini = %s\n', beta, mat2str(K_ini, 5));
fprintf('  polos de A - B*K_ini: max parte real = %.3f (estabilizante)\n\n', max(real(eig(A - B*K_ini))));

tic; Pa = riccati_hamiltoniano(A, B, Q, R); ta = toc;
tic; Pb = riccati_schur(A, B, Q, R);       tb = toc;
tic; [Pc, ~, hist] = riccati_newton(A, B, Q, R, K_ini); tc = toc;

% Biblioteca
if exist('icare', 'file')
    Plib = icare(A, B, Q, R); nom_lib = 'icare';
elseif exist('care', 'file')
    Plib = care(A, B, Q, R);  nom_lib = 'care';
else
    Plib = []; nom_lib = '(sin toolbox)';
end

sol  = {Pa, Pb, Pc};
nom  = {'(a) Hamiltoniana', '(b) Schur (Laub)', '(c) Newton-Kleinman'};
tiem = [ta tb tc];

fprintf('%-22s %10s %10s %10s %10s %10s %10s\n', 'Método', 'vs P0 kit', ['vs ' nom_lib], 'residuo', 'asimetría', 'min eig P', 'max Re cl');
ok2 = true;
for i = 1:3
    v = verificar_riccati(A, B, Q, R, sol{i});
    e_kit = erel(sol{i}, d.P0);
    if isempty(Plib), e_lib = NaN; else, e_lib = erel(sol{i}, Plib); end
    ok = e_kit < tol && (isnan(e_lib) || e_lib < tol) && v.ok;
    ok2 = ok2 && ok;
    fprintf('%-22s %10.2e %10.2e %10.2e %10.2e %10.2e %10.3f  %s\n', nom{i}, e_kit, e_lib, ...
            v.residuo, v.asimetria, v.min_eig_P, v.max_re_cl, marca(ok));
end

fprintf('\nDiferencias entre métodos:\n');
pares = [1 2; 1 3; 2 3];
for k = 1:3
    e = erel(sol{pares(k,1)}, sol{pares(k,2)});
    ok2 = ok2 && e < tol;
    fprintf('  %-20s vs %-20s  %10.2e  %s\n', nom{pares(k,1)}, nom{pares(k,2)}, e, marca(e < tol));
end

% Ganancia
K_c = R \ (B'*Pc);
eK = erel(K_c, d.K0);
ok2 = ok2 && eK < tol;
fprintf('\nK (Newton) = %s\nK0 (kit)   = %s\nerror relativo = %.2e  %s\n', mat2str(K_c, 8), mat2str(d.K0, 8), eK, marca(eK < tol));

% Convergencia de Newton-Kleinman
fprintf('\nConvergencia de Newton-Kleinman (%d iteraciones):\n', numel(hist));
fprintf('%5s %14s %14s\n', 'iter', 'residuo', 'cambio de K');
for k = 1:numel(hist)
    fprintf('%5d %14.3e %14.3e\n', hist(k).k, hist(k).residuo, hist(k).dK);
end
fprintf('\nTiempos [ms]: Hamiltoniana %.2f, Schur %.2f, Newton %.2f\n', 1e3*tiem);

todo_ok = todo_ok && ok2;
fprintf('PRUEBA 2: %s\n', marca(ok2));
fprintf('\nRESULTADO PRUEBAS E1: %s\n', ternario(todo_ok, 'TODAS SUPERADAS', 'HAY PRUEBAS QUE FALLAN'));

save(fullfile(raiz, 'pruebas_E1.mat'), 'Pa', 'Pb', 'Pc', 'Plib', 'hist', 'K_ini', 'beta');

function s = ternario(c, a, b)
if c, s = a; else, s = b; end
end

function s = marca(c)
s = ternario(c, 'OK', 'FALLA');
end
