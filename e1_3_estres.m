%E1_3_ESTRES  Inciso E1.3: estudio de estrés numérico de los solucionadores de Riccati.
%
%   Tres familias de problemas con mal condicionamiento controlado (guía, E1.3):
%     F1  escala de R entre 1e-8 y 1e4                (Q = Q0)
%     F2  cambio de unidades de los estados           x_s = T x,  T = diag(1, 1, s, s)
%         (velocidades expresadas en otras unidades; la física no cambia)
%     F3  autovalores Hamiltonianos cerca del eje imaginario: se reduce el peso del
%         brazo Q(1,1) -> el modo del brazo (autovalor 0 de A) queda casi sin penalizar.
%   Error DIRECTO de cada método frente a una referencia en precisión extendida
%   (src/riccati_vpa.m, 40 dígitos). Convergencia cuadrática de Newton-Kleinman.
%   Evalúa además la predicción E1-P3.
%
%   La referencia vpa se guarda en caché (resultados/E1_3_ref.mat). Para
%   regenerarla desde cero:  recalcular_ref = true.  (Tarda unos minutos.)

clear; clc; close all;
recalcular_ref = isappdata(0, 'E1_regenerar') && getappdata(0, 'E1_regenerar');
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
erel = @(X, Y) norm(X - Y, 'fro') / norm(Y, 'fro');
d = diseno_base_qube();
A0 = d.A; B0 = d.B; Q0 = d.Q0; R0 = d.R0;
K_ini = ganancia_bass(A0, B0, 20);           % ganancia inicial declarada (Bass, beta = 20)

%% Definición de las familias
fam = struct('nombre', {}, 'par', {}, 'etiqueta', {}, 'prob', {});
% F1: escala de R
Rs = 10.^(-8:1:4);
f.nombre = 'F1: escala de R'; f.par = Rs; f.etiqueta = 'R'; f.prob = {};
for R = Rs, f.prob{end+1} = struct('A', A0, 'B', B0, 'Q', Q0, 'R', R, 'T', eye(4)); end
fam(1) = f;
% F2: cambio de unidades de las velocidades
ss = 10.^(-6:1:6);
f.nombre = 'F2: unidades de las velocidades, T = diag(1,1,s,s)'; f.par = ss; f.etiqueta = 's'; f.prob = {};
for s = ss
    T = diag([1 1 s s]);
    f.prob{end+1} = struct('A', T*A0/T, 'B', T*B0, 'Q', (T')\Q0/T, 'R', R0, 'T', T);
end
fam(2) = f;
% F3: peso del brazo -> autovalores de H cerca del eje imaginario
fs = 10.^(0:-1:-12);
f.nombre = 'F3: Q(1,1) = f*Q0(1,1) (autovalores de H -> eje imaginario)'; f.par = fs; f.etiqueta = 'f'; f.prob = {};
for fq = fs
    Q = Q0; Q(1,1) = fq*Q0(1,1);
    f.prob{end+1} = struct('A', A0, 'B', B0, 'Q', Q, 'R', R0, 'T', eye(4));
end
fam(3) = f;

%% Referencias en precisión extendida (con caché)
archivo_ref = fullfile(raiz, 'resultados', 'E1_3_ref.mat');
if ~recalcular_ref && isfile(archivo_ref)
    load(archivo_ref, 'Pref', 'paso_ref');
    fprintf('Referencias vpa cargadas de la caché (%s).\n', archivo_ref);
else
    fprintf('Calculando referencias vpa (40 dígitos)...\n');
    Pref = cell(1, 3); paso_ref = cell(1, 3);
    for i = 1:3
        for j = 1:numel(fam(i).prob)
            pr = fam(i).prob{j};
            [Pref{i}{j}, paso_ref{i}(j)] = riccati_vpa(pr.A, pr.B, pr.Q, pr.R, icare(pr.A, pr.B, pr.Q, pr.R));
            fprintf('  %s, %s = %.0e: última corrección %.1e\n', fam(i).nombre(1:2), fam(i).etiqueta, ...
                    fam(i).par(j), paso_ref{i}(j));
        end
    end
    save(archivo_ref, 'Pref', 'paso_ref');
end
fprintf('Peor última corrección de la referencia: %.1e (debe ser << 1e-16)\n\n', max([paso_ref{:}]));

%% Ejecución de los métodos
nom = {'Hamiltoniana', 'Schur', 'Schur simetr.', 'Newton-K.', 'icare'};
res = struct();
for i = 1:3
    np_ = numel(fam(i).prob);
    E = nan(np_, 5); Res = nan(np_, 5); it = nan(np_, 1);
    diag_ = nan(np_, 4);                      % cond(X1), cond(U11), ||L^-1||, min|Re eig(H)|
    for j = 1:np_
        pr = fam(i).prob{j}; A = pr.A; B = pr.B; Q = pr.Q; R = pr.R;
        Pr = Pref{i}{j};
        Pa = riccati_hamiltoniano(A, B, Q, R);
        Pb = riccati_schur(A, B, Q, R);
        Pbs = (Pb + Pb')/2;
        Ti = pr.T;                                       % ganancia inicial en las nuevas unidades
        [Pc, ~, h] = riccati_newton(A, B, Q, R, K_ini/Ti);
        Pl = icare(A, B, Q, R);
        Ps_ = {Pa, Pb, Pbs, Pc, Pl};
        for m = 1:5
            E(j, m) = erel(Ps_{m}, Pr);
            Res(j, m) = residuo_riccati(A, B, Q, R, Ps_{m});
        end
        it(j) = numel(h);
        % Diagnósticos de condicionamiento
        n = 4; H = [A, -B/R*B'; -Q, -A'];
        [V, D] = eig(H); X = V(:, real(diag(D)) < 0);
        [U, Tt] = schur(H, 'real'); U = ordschur(U, Tt, 'lhp');
        [~, ~, nLinv] = operador_lyapunov(A - B/R*B'*Pr);
        diag_(j, :) = [cond(X(1:n, :)), cond(U(1:n, 1:n)), nLinv, min(abs(real(eig(H))))];
    end
    res(i).E = E; res(i).Res = Res; res(i).it = it; res(i).diag = diag_;

    fprintf('=== %s ===\n', fam(i).nombre);
    fprintf('%8s |%10s %10s %10s %10s %10s | %5s | %9s %9s %9s %9s\n', fam(i).etiqueta, nom{:}, 'itN', ...
            'cond(X1)', 'cond(U11)', '||L^-1||', 'min|ReH|');
    for j = 1:np_
        fprintf('%8.0e |%10.1e %10.1e %10.1e %10.1e %10.1e | %5d | %9.1e %9.1e %9.1e %9.1e\n', ...
                fam(i).par(j), E(j, :), it(j), diag_(j, :));
    end
    fprintf('\n');
end

%% Predicción E1-P3: con R = 1e-8, ¿Hamiltoniana > 1e-6 y Schur < 1e-9?
j8 = 1;                                  % Rs(1) = 1e-8
eH = res(1).E(j8, 1); eS = res(1).E(j8, 2);
pendH = polyfit(log10(Rs(1:9)), log10(res(1).E(1:9, 1)), 1);
pendS = polyfit(log10(Rs(1:9)), log10(res(1).E(1:9, 2)), 1);
fprintf('=== Predicción E1-P3 ===\n');
fprintf('R = 1e-8: error Hamiltoniana = %.1e (predicho > 1e-6), Schur = %.1e (predicho < 1e-9)\n', eH, eS);
fprintf('Pendiente log10(error) vs log10(R), R en [1e-8, 1]: Hamiltoniana %.2f, Schur %.2f\n', pendH(1), pendS(1));
fprintf('(pendiente más negativa = el error crece más rápido al bajar R)\n\n');

%% Convergencia cuadrática de Newton-Kleinman (frente a la referencia vpa)
fprintf('=== Convergencia de Newton-Kleinman (diseño base, error frente a vpa) ===\n');
[~, jb] = min(abs(log10(Rs) - log10(R0)));   % R = R0 = 1e-2
[~, ~, h] = riccati_newton(A0, B0, Q0, R0, K_ini);
ek = arrayfun(@(x) erel(x.P, Pref{1}{jb}), h);
fprintf('%5s %12s %16s\n', 'iter', 'error', 'e(k)/e(k-1)^2');
for k = 1:numel(ek)
    if k == 1, fprintf('%5d %12.3e %16s\n', k, ek(k), '-');
    else,      fprintf('%5d %12.3e %16.3e\n', k, ek(k), ek(k)/ek(k-1)^2); end
end
fprintf('Cociente e(k)/e(k-1)^2 aproximadamente constante en la fase final -> convergencia cuadrática.\n');

%% Figuras
col = lines(5); mk = {'o-', 's-', 'd--', '^-', 'k.-'};
figure('Color', 'w', 'Position', [60 60 1200 380]);
for i = 1:3
    subplot(1, 3, i);
    for m = 1:5
        loglog(fam(i).par, max(res(i).E(:, m), 1e-17), mk{m}, 'Color', col(m, :), 'LineWidth', 1.2); hold on;
    end
    if i == 3, set(gca, 'XDir', 'reverse'); end
    grid on; xlabel(fam(i).etiqueta); ylabel('error directo relativo de P');
    yline(1e-10, 'r:'); title(fam(i).nombre, 'FontSize', 9);
    if i == 1, legend(nom, 'Location', 'northeast', 'FontSize', 8); end
end
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_3_estres.png'), 'Resolution', 200);

figure('Color', 'w', 'Position', [60 500 520 360]);
semilogy(1:numel(ek), ek, 'o-', 'LineWidth', 1.5); grid on;
xlabel('iteración'); ylabel('error relativo frente a vpa');
title('E1.3: convergencia de Newton-Kleinman (diseño base)');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_3_newton.png'), 'Resolution', 200);

save(fullfile(raiz, 'resultados', 'E1_3.mat'), 'res', 'fam', 'ek', 'eH', 'eS', 'pendH', 'pendS');
fprintf('\nGuardado: resultados/E1_3.mat, figuras/E1_3_estres.png, figuras/E1_3_newton.png\n');

% Números citados en el informe: anotar -> results.json -> informe/valores_E1.tex
anotar('e13_n_problemas', numel(fam(1).prob) + numel(fam(2).prob) + numel(fam(3).prob), 'd');
anotar('e13_ref_correccion', max([paso_ref{:}]), 'e1');
anotar('e13_P3_ham', eH, 'e1'); anotar('e13_P3_schur', eS, 'e1');
anotar('e13_P3_pend_ham', pendH(1), 'f2'); anotar('e13_P3_pend_schur', pendS(1), 'f2');
anotar('e13_F1_cifras', log10(eS/2^-52), 'f0');
anotar('e13_F2_schur_smax', res(2).E(end,2), 'e1'); anotar('e13_F2_cifras', log10(res(2).E(end,2)/2^-52), 'f0');
anotar('e13_F3_max', max(res(3).E(:)), 'e1');
anotar('e13_condU11_peor', res(1).diag(1,2), 'f1');
for k = 6:8, anotar(sprintf('e13_nk_cociente%d', k), ek(k)/ek(k-1)^2, 'f2'); end
