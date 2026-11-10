%E1_3E_ICARE_ESCALADO  Inciso E1.3 (cierre definitivo): reproducir icare con piezas propias.
%
%   Según la documentación de icare (MathWorks, "Algorithms"): (1) trabaja con un haz
%   extendido, y (2) escala automáticamente los datos con vectores info.Sx (estados) e
%   info.Sr (entrada); la solución es X = Dx*V*U^-1*Dx, K = -Dr*W*U^-1*Dx, con
%   Dx = diag(Sx), Dr = diag(Sr). La opción 'noscaling' apaga ese escalado.
%   Convención que se deduce de esas fórmulas:  z = Dx x,  u = Dr w  ->
%       Az = Dx A Dx^-1,  Bz = Dx B Dr,  Qz = Dx^-1 Q Dx^-1,  Rz = Dr R Dr,  P = Dx Pz Dx.
%   Experimento:
%     icare            : con su escalado (por defecto)
%     icare noscaling  : sin escalado        -> ¿se degrada como nuestro haz N0?
%     Haz N0           : nuestro haz extendido sin escalado (src/riccati_pencil.m)
%     Haz + Sx,Sr      : nuestro haz con EL MISMO escalado que eligió icare -> ¿alcanza a icare?
%   Si "icare noscaling" ~ "Haz N0" y "Haz + Sx,Sr" ~ "icare", queda explicado por completo
%   qué hace icare: haz extendido (no forma S) + escalado diagonal de estados y entrada.

clear; clc; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
load(fullfile(raiz, 'resultados', 'E1_3.mat'), 'fam');
load(fullfile(raiz, 'resultados', 'E1_3_ref.mat'), 'Pref');
erel = @(X, Y) norm(X - Y, 'fro') / norm(Y, 'fro');

nom = {'icare', 'icare nosc.', 'Haz N0', 'Haz + Sx,Sr'};
res = struct();
for i = 1:3
    np_ = numel(fam(i).prob); E = nan(np_, 4); rangoSx = nan(np_, 1); Sr_ = nan(np_, 1);
    for j = 1:np_
        pr = fam(i).prob{j}; A = pr.A; B = pr.B; Q = pr.Q; R = pr.R; Pr = Pref{i}{j};
        [X1, ~, ~, info] = icare(A, B, Q, R);
        X2 = icare(A, B, Q, R, [], [], [], 'noscaling');   % puede devolver [] si falla
        try, X3 = riccati_pencil(A, B, Q, R); catch, X3 = []; end
        Dx = diag(info.Sx); Dr = diag(info.Sr);
        Pz = riccati_pencil(Dx*A/Dx, Dx*B*Dr, Dx\Q/Dx, Dr*R*Dr);
        X4 = Dx*Pz*Dx;
        Xs = {X1, X2, X3, X4};
        for m = 1:4
            if isempty(Xs{m}) || ~all(isfinite(Xs{m}(:)))
                E(j, m) = Inf;                    % el método no devolvió solución
            else
                E(j, m) = erel(Xs{m}, Pr);
            end
        end
        rangoSx(j) = max(info.Sx)/min(info.Sx); Sr_(j) = info.Sr(1);
    end
    res(i).E = E; res(i).rangoSx = rangoSx; res(i).Sr = Sr_;
    fprintf('=== %s ===\n', fam(i).nombre);
    fprintf('%8s |%13s%13s%13s%13s | %12s %10s\n', fam(i).etiqueta, nom{:}, 'max/min Sx', 'Sr');
    for j = 1:np_
        fprintf('%8.0e |%13.1e%13.1e%13.1e%13.1e | %12.1e %10.1e\n', fam(i).par(j), E(j, :), rangoSx(j), Sr_(j));
    end
    fprintf('Peor caso:  icare %.1e | icare nosc. %.1e | Haz N0 %.1e | Haz + Sx,Sr %.1e\n', max(E));
    fprintf('Fallos (sin solución, Inf): icare %d | icare nosc. %d | Haz N0 %d | Haz + Sx,Sr %d  (de %d)\n\n', ...
            sum(isinf(E)), np_);
end

%% Diagnóstico de nuestro escalado N2: balance(A) en F2 con s = 1e6
A6 = fam(2).prob{end}.A;
[D6, ~] = balance(A6, 'noperm');
fprintf('F2, s = 1e6: diag(D) de balance(A,''noperm'') = %s\n', mat2str(diag(D6).', 3));
fprintf('Columna 1 de A (theta no aparece en la dinámica): %s\n', mat2str(A6(:,1).', 3));
fprintf('icare eligió max/min Sx = %s, Sr = %s\n', mat2str(res(2).rangoSx(end), 3), mat2str(res(2).Sr(end), 3));

%% Figura
col = lines(4); mk = {'k.-', 'k:', 'p--', 'p-'};
figure('Color', 'w', 'Position', [60 60 1200 380]);
for i = 1:3
    subplot(1, 3, i);
    for m = 1:4
        loglog(fam(i).par, max(res(i).E(:, m), 1e-17), mk{m}, 'Color', col(m, :), 'LineWidth', 1.3); hold on;
    end
    if i == 3, set(gca, 'XDir', 'reverse'); end
    grid on; xlabel(fam(i).etiqueta); ylabel('error directo relativo de P'); yline(1e-10, 'r:');
    title(fam(i).nombre(1:2));
    if i == 1, legend(nom, 'Location', 'northeast', 'FontSize', 8); end
end
sgtitle('E1.3: icare = haz extendido + escalado de estados y entrada');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_3_icare_escalado.png'), 'Resolution', 200);
save(fullfile(raiz, 'resultados', 'E1_3e.mat'), 'res');
fprintf('\nGuardado: resultados/E1_3e.mat y figuras/E1_3_icare_escalado.png\n');

% Números citados en el informe: anotar -> results.json -> informe/valores_E1.tex
anotar('e13e_F3_haz_max', max(res(3).E(:,3)), 'e1'); anotar('e13e_F3_nosc_max', max(res(3).E(:,2)), 'e1');
anotar('e13e_F2_haz_s5', res(2).E(end-1,3), 'e1'); anotar('e13e_F2_nosc_s5', res(2).E(end-1,2), 'e1');
anotar('e13e_F2_nosc_fallos', sum(isinf(res(2).E(:,2))), 'd');
for i = 1:3
    anotar(sprintf('e13e_F%d_hazSx_peor', i), max(res(i).E(:,4)), 'e1');
    anotar(sprintf('e13e_F%d_icare_peor', i), max(res(i).E(:,1)), 'e1');
end
anotar('e13e_hazSx_peor', max([max(res(1).E(:,4)), max(res(2).E(:,4)), max(res(3).E(:,4))]), 'e1');
anotar('e13e_D6_2', D6(2,2), 'e0');
