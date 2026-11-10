function R = simular_lote(K, X0, p, opts)
%SIMULAR_LOTE  Simulación VECTORIZADA de muchas condiciones iniciales a la vez, con las mismas
%   ecuaciones y el mismo lazo digital que simular_qube en modo ideal (estado real, sin ruido ni
%   cuantización): u_c = -K x en cada muestra, saturación a +-Vmax, retención de orden cero y
%   RK4 con nsub subpasos por periodo.  Se verifica contra simular_qube en e1_6_region.m.
%   X0: 4 x N condiciones iniciales.  opts: T (5 s), nsub (4).
%   R.xf (estado final), R.max_th, R.max_uc, R.frac_sat, R.recuperado (al final |alpha| < 0.02 rad
%   y |dalpha| < 0.2 rad/s, alpha envuelto), R.exito (además |theta| <= pi/2 en todas las muestras).
if nargin < 4, opts = struct(); end
T = 5; nsub = 4;
if isfield(opts, 'T'), T = opts.T; end
if isfield(opts, 'nsub'), nsub = opts.nsub; end
Ts = p.Ts; h = Ts/nsub; Nk = round(T/Ts); K = reshape(K, 1, []);
x = X0; N = size(X0, 2);
max_th = abs(x(1,:)); max_uc = zeros(1, N); nsat = zeros(1, N);
for k = 1:Nk
    uc = -K*x;
    u = min(max(uc, -p.Vmax), p.Vmax);
    max_uc = max(max_uc, abs(uc)); nsat = nsat + (abs(uc) > p.Vmax);
    for j = 1:nsub
        k1 = dinamica(x, u, p);
        k2 = dinamica(x + h/2*k1, u, p);
        k3 = dinamica(x + h/2*k2, u, p);
        k4 = dinamica(x + h*k3, u, p);
        x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
    end
    max_th = max(max_th, abs(x(1,:)));
end
al = atan2(sin(x(2,:)), cos(x(2,:)));
R.xf = x; R.max_th = max_th; R.max_uc = max_uc; R.frac_sat = nsat/Nk;
R.recuperado = all(isfinite(x), 1) & abs(al) < 0.02 & abs(x(4,:)) < 0.2;
R.exito = R.recuperado & max_th <= p.theta_max;
end

function dx = dinamica(x, u, p)
% Mismas ecuaciones que modelo_qube (tau_d = 0), con la matriz de masa invertida en forma cerrada.
w = x(3,:); ad = x(4,:); s = sin(x(2,:)); c = cos(x(2,:));
tau = p.kt*(u - p.km*w)/p.Rm;
f1 = tau - p.Dr*w - 2*p.Jp*s.*c.*w.*ad - p.mp*p.r*p.lp*s.*ad.^2;
f2 = p.mp*p.g*p.lp*s + p.Jp*s.*c.*w.^2 - p.Dp*ad;
M11 = p.Jr + p.mp*p.r^2 + p.Jp*s.^2; M12 = -p.mp*p.r*p.lp*c; M22 = p.Jp;
dt = M11*M22 - M12.^2;
dx = [w; ad; (M22*f1 - M12.*f2)./dt; (-M12.*f1 + M11.*f2)./dt];
end
