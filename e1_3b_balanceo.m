%E1_3B_BALANCEO  Inciso E1.3 (continuación): ¿por qué Schur falla y la Hamiltoniana no?
%
%   Hipótesis: la diferencia NO es el método (vectores propios vs Schur), sino que
%   eig() de MATLAB BALANCEA la matriz por defecto (semejanza diagonal que iguala las
%   normas de filas y columnas) y schur() NO. Al cambiar R o las unidades, H queda mal
%   escalada (entradas de tamaños muy distintos) y un método sin balanceo pierde cifras.
%   Experimento 2 x 2:  {vectores propios, Schur} x {con balanceo, sin balanceo}.
%   Si la hipótesis es correcta: Hamiltoniana SIN balanceo se degrada como Schur, y
%   Schur CON balanceo mejora como la Hamiltoniana.
%
%   Además (F3): error COMPONENTE A COMPONENTE de P(1,1), la entrada asociada al modo
%   del brazo, que es la mal determinada cuando su peso tiende a cero.
%   Requiere haber corrido antes e1_3_estres (usa resultados/E1_3.mat y E1_3_ref.mat).

clear; clc; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
load(fullfile(raiz, 'resultados', 'E1_3.mat'), 'fam');
load(fullfile(raiz, 'resultados', 'E1_3_ref.mat'), 'Pref');
erel = @(X, Y) norm(X - Y, 'fro') / norm(Y, 'fro');
d = diseno_base_qube(); K_ini = ganancia_bass(d.A, d.B, 20);

var = {'Hamilt. con bal.', 'Hamilt. sin bal.', 'Schur sin bal.', 'Schur con bal.'};
res = struct();
for i = 1:3
    np_ = numel(fam(i).prob); E = nan(np_, 4); escala = nan(np_, 1);
    for j = 1:np_
        pr = fam(i).prob{j}; A = pr.A; B = pr.B; Q = pr.Q; R = pr.R; Pr = Pref{i}{j};
        Ps_ = {riccati_hamiltoniano(A, B, Q, R, 'balance'), riccati_hamiltoniano(A, B, Q, R, 'nobalance'), ...
               riccati_schur(A, B, Q, R, 'nobalance'),      riccati_schur(A, B, Q, R, 'balance')};
        for m = 1:4, E(j, m) = erel(Ps_{m}, Pr); end
        H = [A, -B/R*B'; -Q, -A'];
        a = abs(H(H ~= 0)); escala(j) = max(a)/min(a);    % dispersión de magnitudes en H
    end
    res(i).E = E; res(i).escala = escala;
    fprintf('=== %s ===\n', fam(i).nombre);
    fprintf('%8s | %16s %16s %16s %16s | %12s\n', fam(i).etiqueta, var{:}, 'max/min |H|');
    for j = 1:np_
        fprintf('%8.0e | %16.1e %16.1e %16.1e %16.1e | %12.1e\n', fam(i).par(j), E(j, :), escala(j));
    end
    fprintf('\n');
end

%% F3: error componente a componente en P(1,1)
fprintf('=== F3: error relativo de la entrada P(1,1) (modo del brazo) ===\n');
fprintf('%8s | %12s %12s %12s %12s %12s | %10s %12s\n', 'f', 'Hamilt.', 'Schur', 'Schur bal.', 'Newton-K.', ...
        'icare', 'P11 ref', 'P11/||P||');
e11 = nan(numel(fam(3).prob), 5);
for j = 1:numel(fam(3).prob)
    pr = fam(3).prob{j}; A = pr.A; B = pr.B; Q = pr.Q; R = pr.R; Pr = Pref{3}{j};
    Ps_ = {riccati_hamiltoniano(A, B, Q, R), riccati_schur(A, B, Q, R), riccati_schur(A, B, Q, R, 'balance'), ...
           riccati_newton(A, B, Q, R, K_ini), icare(A, B, Q, R)};
    for m = 1:5, e11(j, m) = abs(Ps_{m}(1,1) - Pr(1,1))/abs(Pr(1,1)); end
    fprintf('%8.0e | %12.1e %12.1e %12.1e %12.1e %12.1e | %10.2e %12.1e\n', fam(3).par(j), e11(j, :), ...
            Pr(1,1), Pr(1,1)/norm(Pr, 'fro'));
end
fprintf(['\nLectura: el error relativo de TODA la matriz puede ser pequeño aunque una entrada\n' ...
         'pequeña (P11) esté mal; la norma de Frobenius queda dominada por las entradas grandes.\n']);

%% Figura
col = lines(4); mk = {'o-', 'o--', 's-', 's--'};
figure('Color', 'w', 'Position', [60 60 1200 380]);
for i = 1:3
    subplot(1, 3, i);
    for m = 1:4
        loglog(fam(i).par, max(res(i).E(:, m), 1e-17), mk{m}, 'Color', col(m, :), 'LineWidth', 1.3); hold on;
    end
    if i == 3, set(gca, 'XDir', 'reverse'); end
    grid on; xlabel(fam(i).etiqueta); ylabel('error directo relativo de P'); yline(1e-10, 'r:');
    title(fam(i).nombre(1:2), 'FontSize', 10);
    if i == 1, legend(var, 'Location', 'northeast', 'FontSize', 8); end
end
sgtitle('E1.3: efecto del balanceo de H (vectores propios vs Schur)');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_3_balanceo.png'), 'Resolution', 200);
save(fullfile(raiz, 'resultados', 'E1_3b.mat'), 'res', 'e11');
fprintf('\nGuardado: resultados/E1_3b.mat y figuras/E1_3_balanceo.png\n');

% Números citados en el informe: anotar -> results.json -> informe/valores_E1.tex
anotar('e13b_F1_hambal_Rmin', res(1).E(1,1), 'e1');
anotar('e13b_F2_bal_peor', max(max(res(2).E(:, [1 4]))), 'e1');
anotar('e13b_P11_schur_max', max(e11(:,2)), 'e1'); anotar('e13b_P11_nk_max', max(e11(:,4)), 'e1');
