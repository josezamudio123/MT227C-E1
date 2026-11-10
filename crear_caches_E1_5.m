%CREAR_CACHES_E1_5  (Uso único) Arma resultados/E1_5_cache.mat y E1_5b_cache.mat a partir de los
%   resultados ya guardados (E1_5.mat y E1_5b.mat), para no repetir ~21 minutos de optimización.
%   Nada se escribe a mano: el reparto de evaluaciones entre los dos arranques de fminsearch se
%   obtiene ubicando en el historial el punto de partida del segundo arranque, y el costo del
%   base en las semillas 1..5 se recalcula (20 simulaciones).
clear; clc;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
R = @(f) load(fullfile(raiz, 'resultados', f));
a = R('E1_5.mat'); e4 = R('E1_4.mat');
% Segundo arranque: el mejor de la malla (misma regla que en e1_5_restricciones)
jf = find(a.fact); [~, i] = min(a.Jrel_g(jf)); kg = jf(i);
x2 = log10([e4.RTH(kg), e4.RAL(kg), 1e-6, 1e-6]);
X = vertcat(a.H.x);
k2 = find(all(abs(X - x2) < 1e-12, 2), 1);
assert(~isempty(k2), 'No se encontró el punto de partida del segundo arranque en el historial.');
nB = [k2 - 1, numel(a.H) - k2 + 1];
F = [a.H.factible]; J = [a.H.Jrel];
bJ = [min([J(F(1:k2-1)) inf]), min([J(k2-1 + find(F(k2:end))) inf])];
H = a.H; Jrel_g = a.Jrel_g; okR4 = a.okR4; Jsem = a.Jsem; val = a.val;
save(fullfile(raiz, 'resultados', 'E1_5_cache.mat'), 'Jrel_g', 'okR4', 'H', 'nB', 'bJ', 'Jsem', 'val');
fprintf('E1_5_cache.mat: evaluaciones por arranque %s, mejor Jrel %s\n', mat2str(nB), mat2str(bJ, 4));
b = R('E1_5b.mat'); d = diseno_base_qube();
Jb = zeros(numel(b.sem_opt), 4);
for s = 1:numel(b.sem_opt)
    ctrl = controlador_lineal(d.K0);
    for c = 1:4
        m = metricas_qube(simular_qube(ctrl, a.cfg.est, escenario_qube(a.cfg.esc{c}), struct('semilla', b.sem_opt(s))));
        Jb(s, c) = m.J;
    end
end
Jm = b.Jm; Jse = b.Jse; fac = b.fac; Kx = b.Kx; sg = b.sg; zt = b.zt; Jv_ = b.Jv_; ok3 = b.ok3; thm = b.thm;
save(fullfile(raiz, 'resultados', 'E1_5b_cache.mat'), 'Jb', 'Jm', 'Jse', 'fac', 'Kx', 'sg', 'zt', 'Jv_', 'ok3', 'thm');
fprintf('E1_5b_cache.mat creado.\n');
