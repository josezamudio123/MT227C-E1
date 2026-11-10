%E1_3D_ESCALADO  Inciso E1.3 (cierre): ¿qué escalado necesita el haz extendido para
%   alcanzar a icare?  Se agregan, una a una, transformaciones EXACTAS del problema
%   (src/escalar_riccati.m) y se mide el error frente a la referencia vpa.
%     Haz N0: sin escalado (= e1_3c)        Haz N1: + entrada normalizada (R = I)
%     Haz N2: + escalado diagonal de estados  Haz N3: + escalado escalar ||S|| = ||Q||
%   Control: Hamiltoniana (eig, balanceada) con el escalado N3.
%   Requiere resultados/E1_3.mat y E1_3_ref.mat (de e1_3_estres).

clear; clc; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
load(fullfile(raiz, 'resultados', 'E1_3.mat'), 'fam');
load(fullfile(raiz, 'resultados', 'E1_3_ref.mat'), 'Pref');
erel = @(X, Y) norm(X - Y, 'fro') / norm(Y, 'fro');

nom = {'Haz N0', 'Haz N1', 'Haz N2', 'Haz N3', 'Hamilt.+N3', 'icare'};
res = struct();
for i = 1:3
    np_ = numel(fam(i).prob); E = nan(np_, 6);
    for j = 1:np_
        pr = fam(i).prob{j}; Pr = Pref{i}{j};
        for nv = 0:3
            [As, Bs, Qs, Rs, des] = escalar_riccati(pr.A, pr.B, pr.Q, pr.R, nv);
            E(j, nv+1) = erel(des(riccati_pencil(As, Bs, Qs, Rs)), Pr);
        end
        [As, Bs, Qs, Rs, des] = escalar_riccati(pr.A, pr.B, pr.Q, pr.R, 3);
        E(j, 5) = erel(des(riccati_hamiltoniano(As, Bs, Qs, Rs)), Pr);
        E(j, 6) = erel(icare(pr.A, pr.B, pr.Q, pr.R), Pr);
    end
    res(i).E = E;
    fprintf('=== %s ===\n', fam(i).nombre);
    fprintf('%8s |%12s%12s%12s%12s%12s%12s\n', fam(i).etiqueta, nom{:});
    for j = 1:np_
        fprintf('%8.0e |%12.1e%12.1e%12.1e%12.1e%12.1e%12.1e\n', fam(i).par(j), E(j, :));
    end
    c = reshape([nom; num2cell(max(E))], 1, []);
    fprintf('Peor caso de la familia:  %s\n', sprintf('%s %.1e | ', c{:}));
    fprintf('\n');
end

%% Figura
col = lines(6); mk = {'p:', 'p--', 'p-.', 'p-', 'o-', 'k.-'};
figure('Color', 'w', 'Position', [60 60 1200 380]);
for i = 1:3
    subplot(1, 3, i);
    for m = 1:6
        loglog(fam(i).par, max(res(i).E(:, m), 1e-17), mk{m}, 'Color', col(m, :), 'LineWidth', 1.3); hold on;
    end
    if i == 3, set(gca, 'XDir', 'reverse'); end
    grid on; xlabel(fam(i).etiqueta); ylabel('error directo relativo de P'); yline(1e-10, 'r:');
    title(fam(i).nombre(1:2));
    if i == 1, legend(nom, 'Location', 'northeast', 'FontSize', 8); end
end
sgtitle('E1.3: haz extendido con escalado progresivo frente a icare');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_3_escalado.png'), 'Resolution', 200);
save(fullfile(raiz, 'resultados', 'E1_3d.mat'), 'res');
fprintf('Guardado: resultados/E1_3d.mat y figuras/E1_3_escalado.png\n');

% Números citados en el informe: anotar -> results.json -> informe/valores_E1.tex
anotar('e13d_F1_N3_peor', max(res(1).E(:,4)), 'e1');
