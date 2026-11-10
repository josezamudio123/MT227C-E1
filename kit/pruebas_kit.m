function pruebas_kit()
%PRUEBAS_KIT Pruebas de instalación y consistencia del kit v1.1.1. Ejecutar antes de usarlo.
%   Las pruebas gráficas se omiten (OMITIDA) si no hay entorno gráfico disponible.
close all;
p = parametros_qube(); d = diseno_base_qube(); ref = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), 'diseno_base_ref.json')));
[A, B] = lineal_qube(p);
R = struct('ok', 0, 'n', 0);
reg = @(R, cond, msg) deal(struct('ok', R.ok + cond, 'n', R.n + 1), msg);

% 1. Modelo lineal frente al jacobiano numérico
J = zeros(4); h = 1e-6;
for i = 1:4
    e = zeros(4,1); e(i) = h;
    J(:,i) = (modelo_qube(e, 0, p) - modelo_qube(-e, 0, p))/(2*h);
end
err = max(abs(J(:) - A(:)))/max(abs(A(:)));
[R, m] = reg(R, err < 1e-6, sprintf('jacobiano vs modelo lineal: error relativo %.1e', err)); informar(err < 1e-6, m);
% 2. Regla de signos
c = B(3) > 0 && B(4) > 0;
[R, m] = reg(R, c, sprintf('regla de signos: B3 = %.3f, B4 = %.3f', B(3), B(4))); informar(c, m);
% 3. Modelo frente a la referencia
err = norm(A - d.A)/norm(d.A) + norm(B - d.B)/norm(d.B);
[R, m] = reg(R, err < 1e-10, '(A,B) coincide con diseno_base_ref.json'); informar(err < 1e-10, m);

ctrl = controlador_lineal(d.K0); est = estimador_base(d);
nombres = {'C1','C2','C3','C3b'};
% 4. Escenarios ideales (estado real, sin ruido ni cuantización) frente a la referencia
for i = 1:numel(nombres)
    L = simular_qube(ctrl, est, escenario_qube(nombres{i}), struct('ideal', true));
    r = ref.escenarios_ideales.(nombres{i});
    e1 = abs(max(abs(L.uc)) - r.max_uc)/r.max_uc; e2 = abs(max(abs(L.x(:,1))) - r.max_theta)/r.max_theta;
    c = e1 < 1e-3 && e2 < 1e-3;
    [R, m] = reg(R, c, sprintf('%-4s ideal: max|u_c| = %6.2f V (ref %6.2f), max|theta| = %.3f rad (ref %.3f)', ...
        nombres{i}, max(abs(L.uc)), r.max_uc, max(abs(L.x(:,1))), r.max_theta)); informar(c, m);
end
% 5. Escenarios con estimador base, cuantización y ruido
for i = 1:numel(nombres)
    mm = metricas_qube(simular_qube(ctrl, est, escenario_qube(nombres{i})));
    [R, m] = reg(R, mm.exito, sprintf('%-4s con estimador y ruido: %s, J = %.4f, max|u_c| = %.2f V, max|theta| = %.3f rad', ...
        nombres{i}, mm.estado, mm.J, mm.max_uc, mm.max_theta)); informar(mm.exito, m);
end
% 6. Impulso: registrado en t_imp con el salto de velocidades correcto
L = simular_qube(ctrl, est, escenario_qube('C3'), struct('ideal', true));
k = L.impulso.k; dq = masa_qube(L.impulso.x_antes(2), p) \ [6e-4; 0];
c = abs(L.t(k+1) - 1) < 1e-12 && norm(L.x(k+1,3:4) - (L.impulso.x_antes(3:4) + dq')) < 1e-12;
[R, m] = reg(R, c, sprintf('impulso de C3 en t = %.3f s, salto de dtheta = %.3f rad/s', L.t(k+1), dq(1))); informar(c, m);
% 7. Violación de recorrido solo en la última muestra
L = simular_qube(ctrl, est, escenario_qube('C1'), struct('ideal', true));
L.x(end,1) = 2; mm = metricas_qube(L);
c = ~mm.exito && mm.violacion_duracion > 0 && strcmp(mm.estado, 'fallo');
[R, m] = reg(R, c, 'violación de recorrido en la última muestra detectada'); informar(c, m);
% 8. Costo con retención de orden cero (caso analítico)
F = sintetico(p, 0.05, 2);
mm = metricas_qube(F); Jex = 1*(0.05^2/(pi/36)^2) + (1/100)*2^2*1;
c = abs(mm.J - Jex) < 1e-10;
[R, m] = reg(R, c, sprintf('costo con ZOH: J = %.6f (exacto %.6f)', mm.J, Jex)); informar(c, m);
% 9. Tiempo de establecimiento
F = sintetico(p, 0, 0); F.x(:,2) = 0; F.x(1:101,2) = 0.05;      % fuera de banda hasta t = 0.2 s
mm = metricas_qube(F); c1 = abs(mm.ts - 0.202) < 1e-12;
F.x(end,2) = 0.05; mm2 = metricas_qube(F); c2 = isempty(mm2.ts);
F.x(:,2) = 0.01; mm3 = metricas_qube(F); c3 = mm3.ts == 0;
c = c1 && c2 && c3;
[R, m] = reg(R, c, 'tiempo de establecimiento: caso normal, sin establecer (null) y sin salir de banda (0)'); informar(c, m);
% 10. Geometría: péndulo arriba y abajo
[~, P1, P2a] = geometria_qube(0.3, 0, p); [~, ~, P2b] = geometria_qube(0.3, pi, p);
c = abs(P2a(3) - p.Lp) < 1e-12 && abs(P2b(3) + p.Lp) < 1e-12 && abs(norm(P1) - p.r) < 1e-12;
[R, m] = reg(R, c, 'geometría: extremo del péndulo en z = +Lp (arriba) y z = -Lp (abajo)'); informar(c, m);
% 11. Cuadros de la animación incluyen el primer y el último instante
idx = cuadros_qube(L.t, 1/30);
c = idx(1) == 1 && idx(end) == numel(L.t);
[R, m] = reg(R, c, sprintf('animación: %d cuadros, incluye t = 0 y t = %.3f s', numel(idx), L.t(end))); informar(c, m);
% 12. Validador
tmp = [tempname '.json'];
s = ejemplo_results(d, p);
escribir(tmp, s); c1 = validar_results(tmp, 'E1');
s2 = s; s2.K0 = []; escribir(tmp, s2); c2 = ~validar_results(tmp, 'E1');
s3 = s; s3.C1.J = []; escribir(tmp, s3); c3 = ~validar_results(tmp, 'E1');
s4 = s; s4.C5 = struct('estado', 'ok'); escribir(tmp, s4); c4 = ~validar_results(tmp, 'E1');
s5 = s; s5.A = zeros(3); escribir(tmp, s5); c5 = ~validar_results(tmp, 'E1');
c = c1 && c2 && c3 && c4 && c5;
[R, m] = reg(R, c, 'validador: acepta un archivo correcto y rechaza campo vacío, métrica null, C5 indebido y dimensión errónea');
informar(c, m);
% 12b. Validador en E4: C5 fallido con t_levantamiento null se acepta; C5 exitoso sin t_levantamiento se rechaza
e4 = s; e4 = rmfield(e4, {'resid_care','K_opt','eig_cl_opt','rho_elipse','mc_region'});
e4.J_energia_min = 1.2; e4.T_swingup = 1.5; e4.K_tvlqr_0 = d.K0; e4.N_mpc = 20; e4.t_qp = [1e-4 2e-4 3e-4];
e4.C5 = struct('estado', 'fallo', 't_levantamiento', [], 'J', [], 'ts', [], 'energia', 35.2, ...
               'max_uc', 10, 'max_u', 10, 'max_theta', 1.2, 'exito', false);
escribir(tmp, e4); c1 = validar_results(tmp, 'E4');
e4.C5 = struct('estado', 'ok', 't_levantamiento', [], 'J', 2.1, 'ts', 0.8, 'energia', 30.1, ...
               'max_uc', 12, 'max_u', 10, 'frac_sat', 0.2, 'max_theta', 1.1, 'exito', true);
escribir(tmp, e4); c2 = ~validar_results(tmp, 'E4');
e4.C5.t_levantamiento = 1.4; escribir(tmp, e4); c3 = validar_results(tmp, 'E4');
delete(tmp);
c = c1 && c2 && c3;
[R, m] = reg(R, c, 'validador E4: C5 fallido con t_levantamiento null aceptado; C5 exitoso exige t_levantamiento');
informar(c, m);
% 13. Monte Carlo C4 (3 plantas, prueba rápida)
r4 = resumen_c4(ctrl, est, 3);
c = r4.n == 3 && numel(r4.semillas_planta) == 3 && size(r4.factores, 1) == 3 && r4.n_exito >= 0;
[R, m] = reg(R, c, sprintf('C4: resumen de %d plantas, %d exitosas', r4.n, r4.n_exito)); informar(c, m);
% 14-15. Pruebas gráficas
try
    F = sintetico(p, pi, 0); F.esc.nombre = 'abajo';
    animar_qube(F, struct('visible', false, 'tiempo_real', false, 'fps', 5));
    hp = findobj(gcf, 'Type', 'line', 'Color', [0.85 0.1 0.1]);
    zl = get(gca, 'ZLim'); zd = get(hp, 'ZData'); if ~iscell(zd), zd = {zd}; end
    zmin = min(cellfun(@min, zd));
    c = abs(zmin + p.Lp) < 1e-9 && zl(1) <= -p.Lp;
    close(gcf);
    [R, m] = reg(R, c, sprintf('animación hacia abajo: z mínimo = %.4f m, límite inferior = %.4f m', zmin, zl(1))); informar(c, m);
    L1 = simular_qube(ctrl, est, escenario_qube('C1'));
    L2 = simular_qube(controlador_lineal(1.3*d.K0), est, escenario_qube('C1'));
    fig = animar_qube_interactivo({L1, L2}, {'base', '1.3 K0'});
    S = getappdata(fig, 'S'); set(S.slider, 'Value', numel(L1.t));
    cb = get(S.slider, 'Callback'); cb(S.slider, []);
    S = getappdata(fig, 'S');
    xd = get(S.cursor(1), 'XData');
    c = S.k == numel(L1.t) && abs(xd(1) - L1.t(end)) < 1e-12;
    close(fig);
    [R, m] = reg(R, c, 'visor interactivo: el deslizador lleva escena, título y cursores al último instante'); informar(c, m);
catch err
    fprintf('[OMITIDA] pruebas gráficas: %s\n', err.message);
end
fprintf('\n%d de %d pruebas superadas.\n', R.ok, R.n);
end

function informar(c, msg)
if c, fprintf('[OK]    %s\n', msg); else, fprintf('[FALLA] %s\n', msg); end
end

function F = sintetico(p, alpha, u)
% Registro sintético de 1 s con estado constante y entrada constante.
N = round(1/p.Ts); F.t = (0:N)'*p.Ts; F.x = repmat([0 alpha 0 0], N+1, 1);
F.xh = F.x(1:N,:); F.uc = u*ones(N,1); F.u = F.uc;
F.esc = struct('nombre', 'sint', 't0', 0, 'p', p); F.opts = struct('ideal', true); F.impulso = [];
end

function s = ejemplo_results(d, p)
[A, B, A5, B5] = lineal_qube(p);
s = struct('grupo', 'G0', 'software', 'MATLAB R2024b', 'semillas', [1 2 3], 'A', A, 'B', B, 'eig_A', eig(A), ...
    'A5', A5, 'B5', B5, 'polo_electrico', -7241.4, 'K0', d.K0, 'L_base', d.L0, ...
    'resid_care', [1e-15 2e-15 1e-15], 'K_opt', d.K0, 'eig_cl_opt', [-1 -2 -3 -4], 'rho_elipse', 0.016, 'mc_region', 0.5);
mt = struct('J', 0.03, 'ts', 0.1, 'max_uc', 9, 'max_u', 9, 'frac_sat', 0, 'max_theta', 0.1, 'exito', true, 'estado', 'ok');
s.C1 = mt; s.C2 = mt; s.C3 = mt; s.C3b = mt;
s.C4 = struct('n', 200, 'n_exito', 200, 'tasa_exito', 1, 'estado', 'ok');
s.C5 = struct('estado', 'no_aplica');
end

function escribir(f, s)
fid = fopen(f, 'w'); fprintf(fid, '%s', jsonencode(s)); fclose(fid);
end
