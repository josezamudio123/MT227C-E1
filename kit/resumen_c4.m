function r = resumen_c4(ctrl, est, n, opts)
%RESUMEN_C4 Monte Carlo del escenario C4 con n plantas perturbadas (n = 200 en el trabajo).
%   r = resumen_c4(ctrl, est, n)
%   Planta i: semilla 1000 + i (ver escenario_qube); ruido de la corrida i: semilla i.
%   Denominador de la tasa de éxito: n. Las estadísticas de J, ts, max|u_c| y max|theta|
%   se calculan solo sobre los ensayos exitosos; los fallidos se listan aparte.
if nargin < 3, n = 200; end
if nargin < 4, opts = struct(); end
F = zeros(n, 4); ok = false(n, 1); J = nan(n, 1); ts = nan(n, 1); uc = nan(n, 1); th = nan(n, 1);
for i = 1:n
    esc = escenario_qube('C4', i);
    o = opts; o.semilla = i;
    m = metricas_qube(simular_qube(ctrl, est, esc, o));
    F(i,:) = esc.factores; ok(i) = m.exito;
    if ~isempty(m.J), J(i) = m.J; end
    if ~isempty(m.ts), ts(i) = m.ts; end
    uc(i) = m.max_uc; th(i) = m.max_theta;
end
r.n = n; r.n_exito = sum(ok); r.tasa_exito = mean(ok);
r.fallidos = find(~ok)';
r.semillas_planta = 1000 + (1:n); r.semillas_ruido = 1:n;
r.factores = F;
nombres = {'J', 'ts', 'max_uc', 'max_theta'}; datos = {J, ts, uc, th};
for i = 1:numel(nombres)
    v = datos{i}(ok);
    if isempty(v)
        r.(nombres{i}) = struct('media', [], 'desv', [], 'p95', []);
    else
        v = sort(v); k95 = max(1, ceil(0.95*numel(v)));
        r.(nombres{i}) = struct('media', mean(v), 'desv', std(v), 'p95', v(k95));
    end
end
r.estado = 'ok';
end
