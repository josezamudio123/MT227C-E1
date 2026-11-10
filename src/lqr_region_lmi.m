function [K, Jcota, info] = lqr_region_lmi(A, B, Q, R, X0, region)
%LQR_REGION_LMI  LQR con restricción de región de polos por LMI (Chilali y Gahinet, 1996).
%   Resuelve con LMI Lab (Robust Control Toolbox: setlmis, lmiterm, mincx):
%     min  tr(Z)
%     s.a. [ M + M'     X Q^1/2   Y' R^1/2 ]
%          [ Q^1/2 X    -I        0        ]  < 0       (costo garantizado, M = A X - B Y)
%          [ R^1/2 Y    0         -I       ]
%          [ Z      X0^1/2 ]
%          [ X0^1/2   X    ]  > 0,   X > 0             (tr(Z) >= tr(X0^1/2 X^-1 X0^1/2) = tr(P X0))
%     región D (opcional, MISMA X: Lyapunov común):
%       semiplano  Re(s) < -sigma : M + M' + 2 sigma X < 0
%       sector     zeta >= zeta_min (ángulo th = acos(zeta_min)):
%                  [ sin(th)(M + M')   cos(th)(M - M') ]
%                  [ cos(th)(M' - M)   sin(th)(M + M') ]  < 0
%       disco      |s| < r        : [ -r X   M ; M'  -r X ] < 0
%   Ganancia: K = Y X^-1 (u = -K x).  Jcota = tr(Z) es una COTA SUPERIOR de J0 = tr(P_K X0).
%   Sin región, la solución coincide con el LQR (prueba de respuesta conocida).
%   region: struct con campos opcionales sigma, zeta, r (vacío: sin región).
if nargin < 6, region = struct(); end
if exist('mincx', 'file') ~= 2
    error('lqr_region_lmi: se requiere el Robust Control Toolbox (LMI Lab: mincx).');
end
n = size(A, 1); m = size(B, 2);
Qh = raiz_psd(Q); Rh = raiz_psd(R); Xh = raiz_psd(X0);   % raíz de matrices semidefinidas (Q0 es singular)
setlmis([]);
X = lmivar(1, [n 1]); Y = lmivar(2, [m n]); Z = lmivar(1, [n 1]);
% (1) Costo garantizado
L1 = newlmi;
lmiterm([L1 1 1 X], A, 1, 's'); lmiterm([L1 1 1 Y], -B, 1, 's');
lmiterm([L1 2 1 X], Qh, 1);     lmiterm([L1 2 2 0], -1);
lmiterm([L1 3 1 Y], Rh, 1);     lmiterm([L1 3 3 0], -1);
% (2) Z > X0^1/2 X^-1 X0^1/2
L2 = newlmi;
lmiterm([-L2 1 1 Z], 1, 1); lmiterm([-L2 2 1 0], Xh); lmiterm([-L2 2 2 X], 1, 1);
% (3) X > 0
L3 = newlmi; lmiterm([-L3 1 1 X], 1, 1);
% (4) Región de polos
if isfield(region, 'sigma') && ~isempty(region.sigma)
    L4 = newlmi;
    lmiterm([L4 1 1 X], A, 1, 's'); lmiterm([L4 1 1 Y], -B, 1, 's'); lmiterm([L4 1 1 X], 2*region.sigma, 1);
end
if isfield(region, 'zeta') && ~isempty(region.zeta)
    th = acos(region.zeta); s = sin(th); c = cos(th);
    L5 = newlmi;
    lmiterm([L5 1 1 X], s*A, 1, 's'); lmiterm([L5 1 1 Y], -s*B, 1, 's');
    lmiterm([L5 2 1 X], 1, c*A');     lmiterm([L5 2 1 -Y], -c, B');      % c (X A' - Y' B')
    lmiterm([L5 2 1 X], -c*A, 1);     lmiterm([L5 2 1 Y], c*B, 1);       % - c (A X - B Y)
    lmiterm([L5 2 2 X], s*A, 1, 's'); lmiterm([L5 2 2 Y], -s*B, 1, 's');
end
if isfield(region, 'r') && ~isempty(region.r) && isfinite(region.r)
    L6 = newlmi;
    lmiterm([L6 1 1 X], -region.r, 1);
    lmiterm([L6 2 1 X], 1, A'); lmiterm([L6 2 1 -Y], -1, B');           % M' = X A' - Y' B'
    lmiterm([L6 2 2 X], -region.r, 1);
end
sis = getlmis;
nd = decnbr(sis); cvec = zeros(nd, 1);
for j = 1:nd
    Zj = defcx(sis, j, Z); cvec(j) = trace(Zj);
end
[Jcota, xopt] = mincx(sis, cvec, [1e-8, 500, 0, 0, 1]);
if isempty(xopt)
    K = nan(m, n); info.factible = false; return
end
Xs = dec2mat(sis, xopt, X); Ys = dec2mat(sis, xopt, Y);
K = Ys / Xs;
info.factible = true; info.X = Xs; info.polos = eig(A - B*K);
end

function S = raiz_psd(M)
% Raíz cuadrada simétrica de una matriz semidefinida positiva (sin el aviso de sqrtm).
[V, D] = eig((M + M')/2);
S = V*diag(sqrt(max(diag(D), 0)))*V';
end
