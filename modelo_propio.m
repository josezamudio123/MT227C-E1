%MODELO_PROPIO  Modelo propio del péndulo de Furuta y su verificación (OE1, hito H1).
%
%   Qué hace este script:
%     1) Arma el modelo LINEAL propio (A, B de 4 estados y A5, B5 de 5 estados)
%        con las fórmulas deducidas a mano por Euler-Lagrange y linealizadas
%        por el Jacobiano en el equilibrio superior (alpha = 0).
%     2) Verifica contra el kit (lineal_qube y diseno_base_ref.json).
%     3) Verifica contra el JACOBIANO NUMÉRICO del modelo no lineal propio
%        (f_propio, escrita aquí, independiente del kit) y del kit (modelo_qube).
%     4) Justifica la reducción de 5 a 4 estados comparando polos.
%     5) (Opcional) Si hay Symbolic Math Toolbox, deduce Euler-Lagrange
%        desde la geometría como segundo camino independiente.
%   Criterio de la guía (OE1): error relativo < 1e-6.

clear; clc;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
p   = parametros_qube();
tol = 1e-6;
erel = @(X, Xref) norm(X - Xref, 'fro') / norm(Xref, 'fro');   % error relativo

%% 1) Modelo lineal propio (fórmulas deducidas a mano)
M0  = [p.Jr + p.mp*p.r^2,  -p.mp*p.r*p.lp;      % M(alpha = 0)
       -p.mp*p.r*p.lp,      p.Jp];
Fx  = [0  0               -(p.Dr + p.kt*p.km/p.Rm)   0;     % fuerzas lineales (4 estados)
       0  p.mp*p.g*p.lp    0                        -p.Dp];
Fu  = [p.kt/p.Rm; 0];
A_p = [zeros(2) eye(2); M0\Fx];
B_p = [0; 0; M0\Fu];

Fx5 = [0  0              -p.Dr   0      p.kt;                % 5 estados: xe = [x; ia]
       0  p.mp*p.g*p.lp   0     -p.Dp   0];
A5_p = zeros(5);
A5_p(1:2, 3:4) = eye(2);
A5_p(3:4, :)   = M0\Fx5;
A5_p(5, :)     = [0 0 -p.km/p.Lm 0 -p.Rm/p.Lm];
B5_p = [0; 0; 0; 0; 1/p.Lm];

%% 2) Comparación con el kit
[A_k, B_k, A5_k, B5_k] = lineal_qube(p);
d = diseno_base_qube();

%% 3) Jacobiano numérico (diferencias centrales) en x = 0, u = 0
x0 = zeros(4,1); u0 = 0;
[A_jp, B_jp] = jacobiano(@(x,u) f_propio(x, u, p),  x0, u0);   % no lineal propio
[A_jk, B_jk] = jacobiano(@(x,u) modelo_qube(x, u, p), x0, u0); % no lineal del kit
[A5_jp, B5_jp] = jacobiano(@(x,u) f5_propio(x, u, p), zeros(5,1), u0);

%% Tabla de errores
fprintf('=== OE1: verificación del modelo linealizado (tolerancia %.0e) ===\n\n', tol);
pruebas = {
  'A propio  vs A kit (lineal_qube)',        erel(A_p,  A_k)
  'B propio  vs B kit (lineal_qube)',        erel(B_p,  B_k)
  'A propio  vs A kit (diseno_base_ref)',    erel(A_p,  d.A)
  'B propio  vs B kit (diseno_base_ref)',    erel(B_p,  d.B)
  'A propio  vs Jacobiano num. f_propio',    erel(A_p,  A_jp)
  'B propio  vs Jacobiano num. f_propio',    erel(B_p,  B_jp)
  'A propio  vs Jacobiano num. modelo_qube', erel(A_p,  A_jk)
  'B propio  vs Jacobiano num. modelo_qube', erel(B_p,  B_jk)
  'A5 propio vs A5 kit',                     erel(A5_p, A5_k)
  'B5 propio vs B5 kit',                     erel(B5_p, B5_k)
  'A5 propio vs Jacobiano num. f5_propio',   erel(A5_p, A5_jp)
  'B5 propio vs Jacobiano num. f5_propio',   erel(B5_p, B5_jp)};
ok_total = true;
for i = 1:size(pruebas, 1)
    ok = pruebas{i,2} < tol;  ok_total = ok_total && ok;
    fprintf('%-42s  %10.3e   %s\n', pruebas{i,1}, pruebas{i,2}, ternario(ok, 'OK', 'FALLA'));
end

%% Regla de signos de la guía (B3 > 0 y B4 > 0)
fprintf('\nRegla de signos: B3 = %.4f, B4 = %.4f  -> %s\n', B_p(3), B_p(4), ...
        ternario(B_p(3) > 0 && B_p(4) > 0, 'OK', 'FALLA'));

%% 4) Polos y justificación de la reducción a 4 estados
eigA  = eig(A_p);
eigA5 = eig(A5_p);
[~, iel] = min(real(eigA5));            % polo eléctrico = el más rápido
polo_electrico = eigA5(iel);
fprintf('\nPolos 4 estados: %s\n', mat2str(sort(real(eigA)).', 6));
fprintf('Polos 5 estados: %s\n', mat2str(sort(real(eigA5)).', 6));
fprintf('Polo eléctrico: %.1f rad/s  (-Rm/Lm = %.1f rad/s)\n', real(polo_electrico), -p.Rm/p.Lm);
fprintf('Separación polo eléctrico / polo mecánico más rápido: %.0f veces\n', ...
        abs(real(polo_electrico)) / max(abs(real(eigA))));

%% Mostrar matrices
fprintf('\nA propio =\n'); disp(A_p);
fprintf('B propio =\n');   disp(B_p);

%% 5) Segundo camino: Euler-Lagrange simbólico desde la geometría (opcional)
if exist('syms', 'file') && license('test', 'Symbolic_Toolbox')
    [A_s, B_s] = euler_lagrange_simbolico(p);
    fprintf('\n=== Euler-Lagrange simbólico (desde la geometría) ===\n');
    fprintf('%-42s  %10.3e   %s\n', 'A propio  vs A simbólico', erel(A_p, A_s), ternario(erel(A_p, A_s) < tol, 'OK', 'FALLA'));
    fprintf('%-42s  %10.3e   %s\n', 'B propio  vs B simbólico', erel(B_p, B_s), ternario(erel(B_p, B_s) < tol, 'OK', 'FALLA'));
    ok_total = ok_total && erel(A_p, A_s) < tol && erel(B_p, B_s) < tol;
else
    fprintf('\n(Symbolic Math Toolbox no disponible: se omite la deducción simbólica)\n');
end

fprintf('\nRESULTADO OE1: %s\n', ternario(ok_total, 'TODAS LAS VERIFICACIONES SUPERADAS', 'HAY VERIFICACIONES QUE FALLAN'));

%% Guardar para results.json
modelo.A = A_p; modelo.B = B_p; modelo.eig_A = eigA;
modelo.A5 = A5_p; modelo.B5 = B5_p; modelo.polo_electrico = real(polo_electrico);
save(fullfile(raiz, 'modelo_propio.mat'), 'modelo');

% Números citados en el informe: anotar -> results.json -> informe/valores_E1.tex
anotar('m_A_kit', erel(A_p, A_k), 'e1');
anotar('m_A_jac', erel(A_p, A_jp), 'e1');
anotar('m_polo_e', real(polo_electrico), 'f1');
anotar('m_sep_polo', abs(real(polo_electrico)) / max(abs(real(eigA))), 'f0');
if exist('A_s', 'var'), anotar('m_EL', max(erel(A_p, A_s), erel(B_p, B_s)), 'e1'); end

%% ======================= Funciones locales =======================

function dx = f_propio(x, u, p)
% Modelo no lineal propio de 4 estados (armadura cuasiestática, Lm -> 0).
% Ecuaciones de Euler-Lagrange deducidas a mano (ver informe).
th_d = x(3); al_d = x(4); s = sin(x(2)); c = cos(x(2));
tau = p.kt*(u - p.km*th_d)/p.Rm;                       % par del motor
M = [p.Jr + p.mp*p.r^2 + p.Jp*s^2,  -p.mp*p.r*p.lp*c;
     -p.mp*p.r*p.lp*c,               p.Jp];
h = [tau - p.Dr*th_d - 2*p.Jp*s*c*th_d*al_d - p.mp*p.r*p.lp*s*al_d^2;
     p.mp*p.g*p.lp*s + p.Jp*s*c*th_d^2 - p.Dp*al_d];
acc = M\h;
dx = [th_d; al_d; acc];
end

function dx = f5_propio(xe, u, p)
% Modelo no lineal propio de 5 estados: xe = [theta alpha dtheta dalpha ia].
th_d = xe(3); al_d = xe(4); ia = xe(5); s = sin(xe(2)); c = cos(xe(2));
M = [p.Jr + p.mp*p.r^2 + p.Jp*s^2,  -p.mp*p.r*p.lp*c;
     -p.mp*p.r*p.lp*c,               p.Jp];
h = [p.kt*ia - p.Dr*th_d - 2*p.Jp*s*c*th_d*al_d - p.mp*p.r*p.lp*s*al_d^2;
     p.mp*p.g*p.lp*s + p.Jp*s*c*th_d^2 - p.Dp*al_d];
acc = M\h;
dia = (u - p.Rm*ia - p.km*th_d)/p.Lm;                  % circuito de armadura
dx = [th_d; al_d; acc; dia];
end

function [A, B] = jacobiano(f, x0, u0)
% Jacobiano numérico por diferencias centrales.
n = numel(x0); hx = 1e-6; f0 = f(x0, u0);
A = zeros(numel(f0), n);
for j = 1:n
    e = zeros(n,1); e(j) = hx;
    A(:, j) = (f(x0 + e, u0) - f(x0 - e, u0)) / (2*hx);
end
B = (f(x0, u0 + hx) - f(x0, u0 - hx)) / (2*hx);
end

function [A, B] = euler_lagrange_simbolico(p)
% Deduce las ecuaciones de movimiento desde las POSICIONES (no desde las
% energías ya escritas), integrando a lo largo de la varilla del péndulo.
syms th al dth dal ddth ddal Vm s real
syms Jr mp r Lp g Dr Dp kt km Rm real
q = [th; al]; dq = [dth; dal]; ddq = [ddth; ddal];
% Pivote del péndulo en la punta del brazo y dirección de la varilla
P = [r*cos(th); r*sin(th); 0];
n = [sin(al)*sin(th); -sin(al)*cos(th); cos(al)];      % alpha = 0: vertical arriba
R = P + s*n;                                           % punto a distancia s del pivote
v = jacobian(R, q)*dq;                                 % velocidad de ese punto
dm = mp/Lp;                                            % masa por unidad de longitud
T = 1/2*Jr*dth^2 + int(1/2*dm*(v.'*v), s, 0, Lp);      % energía cinética
V = int(dm*g*R(3), s, 0, Lp);                          % energía potencial
L = simplify(T - V);
Q = [kt*(Vm - km*dth)/Rm - Dr*dth; -Dp*dal];           % fuerzas generalizadas
eqs = sym(zeros(2,1));
for i = 1:2
    dLdqd = diff(L, dq(i));
    ddt = jacobian(dLdqd, [q; dq])*[dq; ddq];          % d/dt por regla de la cadena
    eqs(i) = ddt - diff(L, q(i)) - Q(i);
end
[Mm, rhs] = equationsToMatrix(eqs, ddq);               % Mm*ddq = rhs
f = [dq; Mm\rhs];
z = [q; dq];
As = subs(jacobian(f, z),  [z; Vm], zeros(5,1));
Bs = subs(jacobian(f, Vm), [z; Vm], zeros(5,1));
vars = [Jr mp r Lp g Dr Dp kt km Rm];
vals = [p.Jr p.mp p.r p.Lp p.g p.Dr p.Dp p.kt p.km p.Rm];
A = double(subs(As, vars, vals));
B = double(subs(Bs, vars, vals));
fprintf('\nMatriz de masa simbólica M(alpha):\n'); disp(simplify(Mm));
end

function s = ternario(c, a, b)
if c, s = a; else, s = b; end
end
