%E1_1_METODOS  Inciso E1.1: tres métodos de solución de la ecuación de Riccati
%   ejecutados sobre los MISMOS problemas y comparados.
%     (a) vectores propios de la Hamiltoniana   -> src/riccati_hamiltoniano.m
%     (b) Schur real ordenado (Laub)            -> src/riccati_schur.m
%     (c) Newton-Kleinman con ganancia inicial  -> src/riccati_newton.m
%   Referencia de biblioteca: icare (Control System Toolbox).
%   Salidas: tabla en pantalla, resultados/E1_1.mat, figuras/E1_1_errores.png

clear; clc; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
d = diseno_base_qube();
p = parametros_qube();
[~, ~, A5, B5] = lineal_qube(p);
erel = @(X, Y) norm(X - Y, 'fro') / norm(Y, 'fro');

%% Banco de problemas (todos los métodos resuelven exactamente los mismos)
% Ganancia inicial de Newton declarada para cada problema:
%   - Bass con beta = 20 (> 17.63 = max(-real(eig(A)))) para el péndulo de 4 estados.
%   - Para 5 estados Bass exigiría beta > 7240 (polo eléctrico) y la ecuación de
%     Lyapunov de Bass queda mal condicionada; se usa [K0 0] (diseño base de
%     4 estados ampliado con ganancia nula en la corriente), que es estabilizante.
pb = struct('nombre', {}, 'A', {}, 'B', {}, 'Q', {}, 'R', {}, 'K_ini', {}, 'ini', {});
pb(end+1) = struct('nombre', 'Escalar xdot = x + u, q = 1', 'A', 1, 'B', 1, 'Q', 1, 'R', 1, ...
                   'K_ini', 2, 'ini', 'K = 2');
pb(end+1) = struct('nombre', 'Péndulo, diseño base (Q0, R0)', 'A', d.A, 'B', d.B, 'Q', d.Q0, 'R', d.R0, ...
                   'K_ini', ganancia_bass(d.A, d.B, 20), 'ini', 'Bass, beta = 20');
pb(end+1) = struct('nombre', 'Péndulo, Q0 y R = 100 R0', 'A', d.A, 'B', d.B, 'Q', d.Q0, 'R', 100*d.R0, ...
                   'K_ini', ganancia_bass(d.A, d.B, 20), 'ini', 'Bass, beta = 20');
pb(end+1) = struct('nombre', 'Péndulo, Q0 y R = R0/100', 'A', d.A, 'B', d.B, 'Q', d.Q0, 'R', d.R0/100, ...
                   'K_ini', ganancia_bass(d.A, d.B, 20), 'ini', 'Bass, beta = 20');
pb(end+1) = struct('nombre', 'Péndulo, Q = I, R = 1', 'A', d.A, 'B', d.B, 'Q', eye(4), 'R', 1, ...
                   'K_ini', ganancia_bass(d.A, d.B, 20), 'ini', 'Bass, beta = 20');
pb(end+1) = struct('nombre', 'Péndulo 5 estados (con armadura), Q0 ampliada, R0', 'A', A5, 'B', B5, ...
                   'Q', blkdiag(d.Q0, 0), 'R', d.R0, 'K_ini', [d.K0, 0], 'ini', '[K0 0]');

metodos = {'(a) Hamiltoniana', '(b) Schur', '(c) Newton-K.'};
res = struct();

for i = 1:numel(pb)
    A = pb(i).A; B = pb(i).B; Q = pb(i).Q; R = pb(i).R;
    fprintf('\n=== Problema %d: %s ===\n', i, pb(i).nombre);
    fprintf('Ganancia inicial de Newton: %s (max Re eig(A-BK_ini) = %.2f)\n', ...
            pb(i).ini, max(real(eig(A - B*pb(i).K_ini))));
    Plib = icare(A, B, Q, R);

    P = cell(1,3); t = zeros(1,3); it = [NaN NaN 0];
    P{1} = riccati_hamiltoniano(A, B, Q, R);
    P{2} = riccati_schur(A, B, Q, R);
    [P{3}, ~, hist] = riccati_newton(A, B, Q, R, pb(i).K_ini);
    it(3) = numel(hist);
    t(1) = timeit(@() riccati_hamiltoniano(A, B, Q, R));
    t(2) = timeit(@() riccati_schur(A, B, Q, R));
    t(3) = timeit(@() riccati_newton(A, B, Q, R, pb(i).K_ini));

    fprintf('%-17s %10s %10s %10s %10s %10s %10s %6s\n', 'Método', 'vs icare', 'residuo', ...
            'asimetría', 'min eig P', 'max Re cl', 't [ms]', 'iter');
    for m = 1:3
        v = verificar_riccati(A, B, Q, R, P{m});
        e = erel(P{m}, Plib);
        fprintf('%-17s %10.2e %10.2e %10.2e %10.2e %10.3f %10.3f %6s\n', metodos{m}, e, v.residuo, ...
                v.asimetria, v.min_eig_P, v.max_re_cl, 1e3*t(m), num2str(it(m)));
        res(i).err(m) = e; res(i).residuo(m) = v.residuo; res(i).asim(m) = v.asimetria;
        res(i).t(m) = t(m); res(i).ok(m) = v.ok;
    end
    vl = verificar_riccati(A, B, Q, R, Plib);
    fprintf('%-17s %10s %10.2e %10.2e %10.2e %10.3f\n', 'icare (ref.)', '-', vl.residuo, ...
            vl.asimetria, vl.min_eig_P, vl.max_re_cl);
    fprintf('Máxima diferencia entre los tres métodos: %.2e\n', ...
            max([erel(P{1},P{2}), erel(P{1},P{3}), erel(P{2},P{3})]));
    res(i).nombre = pb(i).nombre; res(i).iter_newton = it(3); res(i).P = P; res(i).Plib = Plib;
    res(i).K = R \ (pb(i).B'*P{2});
end

% Comparación 4 vs 5 estados: ¿cambia el regulador al incluir la armadura?
K5 = res(6).K;
fprintf('\nK (5 estados) = %s\nK0 (4 estados) = %s\n', mat2str(K5, 6), mat2str(d.K0, 6));
fprintf('Diferencia relativa en la parte mecánica: %.2e (ganancia sobre la corriente: %.4f V/A)\n', ...
        erel(K5(1:4), d.K0), K5(5));

%% Figura: error frente a icare por problema y método
E = reshape([res.err], 3, []).';
figure('Color', 'w', 'Position', [100 100 760 380]);
piso = 1e-17;                                   % errores exactamente 0 se dibujan en el piso
hb = bar(max(E, piso)); set(gca, 'YScale', 'log'); grid on;
ylim([1e-18 1e-6]); yline(1e-10, 'r--', 'tolerancia 10^{-10}', 'LabelHorizontalAlignment', 'left');
for m = 1:3                                     % marcar con "0" los errores nulos
    xc = hb(m).XEndPoints; idx = E(:, m) == 0;
    text(xc(idx), piso*ones(1, nnz(idx)), '0', 'HorizontalAlignment', 'center', ...
         'VerticalAlignment', 'bottom', 'FontWeight', 'bold');
end
etiquetas = {'Escalar', 'Base (Q0,R0)', 'R = 100R0', 'R = R0/100', 'Q = I, R = 1', '5 estados'};
xticklabels(etiquetas);
xlabel('Problema'); ylabel('Error relativo de P frente a icare');
legend(metodos, 'Location', 'northwest'); title('E1.1: comparación de los tres métodos');
exportgraphics(gcf, fullfile(raiz, 'figuras', 'E1_1_errores.png'), 'Resolution', 200);

save(fullfile(raiz, 'resultados', 'E1_1.mat'), 'res', 'pb');
fprintf('\nGuardado: resultados/E1_1.mat y figuras/E1_1_errores.png\n');
