%E1_3C_ICARE  Inciso E1.3 (cierre): ¿por qué icare sigue exacta con R = 1e-8
%   cuando los métodos balanceados ya pierden 6 cifras?
%
%   Hipótesis: el problema está en FORMAR la Hamiltoniana. H contiene S = B R^-1 B',
%   cuyo tamaño crece como 1/R (con R = 1e-8, ||S|| ~ 3e12). Ese paso mezcla en una
%   sola matriz números de tamaños incompatibles ANTES de que cualquier balanceo
%   pueda actuar. icare/care no forman S: trabajan con el haz extendido de Arnold y
%   Laub (2n+m), que mantiene R separado.
%   Experimento: comparar, frente a la referencia vpa,
%     - Hamiltoniana con balanceo (eig) y Schur con balanceo   -> forman S
%     - haz extendido propio (src/riccati_pencil.m), SIN balanceo -> no forma S
%     - icare y care (care no tiene opción documentada para apagar el escalado;
%       el efecto del escalado se estudia con icare(...,'noscaling') en e1_3e)
%   Si el haz propio sin balanceo alcanza a icare, la causa es la formación de S.
%   Requiere haber corrido e1_3_estres (usa resultados/E1_3.mat y E1_3_ref.mat).

clear; clc; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
load(fullfile(raiz, 'resultados', 'E1_3.mat'), 'fam');
load(fullfile(raiz, 'resultados', 'E1_3_ref.mat'), 'Pref');
erel = @(X, Y) norm(X - Y, 'fro') / norm(Y, 'fro');

nom = {'Hamilt. bal.', 'Schur bal.', 'Haz propio', 'icare', 'care'};
tiene_care = exist('care', 'file') > 0;
res = struct();
for i = 1:2                                  % F1 (escala de R) y F2 (unidades)
    np_ = numel(fam(i).prob); E = nan(np_, 5); nS = nan(np_, 1);
    for j = 1:np_
        pr = fam(i).prob{j}; A = pr.A; B = pr.B; Q = pr.Q; R = pr.R; Pr = Pref{i}{j};
        Ps_ = cell(1, 5);
        Ps_{1} = riccati_hamiltoniano(A, B, Q, R, 'balance');
        Ps_{2} = riccati_schur(A, B, Q, R, 'balance');
        Ps_{3} = riccati_pencil(A, B, Q, R);
        Ps_{4} = icare(A, B, Q, R);
        if tiene_care
            try, Ps_{5} = care(A, B, Q, R); catch, Ps_{5} = []; end
        end
        for m = 1:5
            if ~isempty(Ps_{m}), E(j, m) = erel(Ps_{m}, Pr); end
        end
        nS(j) = norm(B/R*B', 'fro') / max(norm(A, 'fro'), norm(Q, 'fro'));
    end
    res(i).E = E; res(i).nS = nS;
    fprintf('=== %s ===\n', fam(i).nombre);
    fprintf('%8s |%13s%13s%13s%13s%13s | %12s\n', fam(i).etiqueta, nom{:}, '||S||/||A,Q||');
    for j = 1:np_
        fprintf('%8.0e |%13.1e%13.1e%13.1e%13.1e%13.1e | %12.1e\n', fam(i).par(j), E(j, :), nS(j));
    end
    fprintf('\n');
end
if ~tiene_care, fprintf('(care no disponible: columna care en NaN)\n'); end

% Veredicto automático en el peor caso de F1 (R = 1e-8)
eF1 = res(1).E(1, :);
fprintf('R = 1e-8:  Hamiltoniana bal. %.1e | Schur bal. %.1e | haz propio %.1e | icare %.1e\n', eF1(1:4));
if eF1(3) < 1e-2*min(eF1(1:2))
    fprintf(['-> El haz extendido SIN balanceo recupera la precisión: la pérdida de los métodos\n' ...
             '   balanceados se debe a FORMAR S = B R^-1 B'' (Hamiltoniana), no a la falta de escalado.\n']);
else
    fprintf('-> El haz extendido propio NO recupera la precisión: la hipótesis no se confirma.\n');
end

%% Figura
col = lines(5); mk = {'o-', 's--', 'p-', 'k.-', 'v-'};
figure('Color', 'w', 'Position', [60 60 900 380]);
for i = 1:2
    subplot(1, 2, i);
    for m = 1:5
        if all(isnan(res(i).E(:, m))), continue; end
        loglog(fam(i).par, max(res(i).E(:, m), 1e-17), mk{m}, 'Color', col(m, :), 'LineWidth', 1.3); hold on;
    end
    grid on; xlabel(fam(i).etiqueta); ylabel('error directo relativo de P'); yline(1e-10, 'r:');
    title(fam(i).nombre(1:2));
    if i == 1, legend(nom(~all(isnan(res(1).E), 1)), 'Location', 'northeast', 'FontSize', 8); end
end
sgtitle('E1.3: Hamiltoniana (forma S = BR^{-1}B^T) vs haz extendido (no la forma)');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_3_haz_extendido.png'), 'Resolution', 200);
save(fullfile(raiz, 'resultados', 'E1_3c.mat'), 'res');
fprintf('\nGuardado: resultados/E1_3c.mat y figuras/E1_3_haz_extendido.png\n');
