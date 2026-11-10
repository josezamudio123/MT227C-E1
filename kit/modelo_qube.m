function dx = modelo_qube(x, u, p, tau_d)
%MODELO_QUBE Dinámica no lineal de 4 estados con entrada de tensión.
%   dx = modelo_qube(x, u, p, tau_d)
%   x = [theta; alpha; dtheta; dalpha], u = Vm [V], tau_d = par de perturbación
%   sobre el brazo [N m] (opcional). Armadura en régimen cuasiestático (Lm -> 0).
if nargin < 4, tau_d = 0; end
w = x(3); ad = x(4); s = sin(x(2)); c = cos(x(2));
tau = p.kt*(u - p.km*w)/p.Rm;
f1 = tau + tau_d - p.Dr*w - 2*p.Jp*s*c*w*ad - p.mp*p.r*p.lp*s*ad^2;
f2 = p.mp*p.g*p.lp*s + p.Jp*s*c*w^2 - p.Dp*ad;
acc = masa_qube(x(2), p) \ [f1; f2];
dx = [w; ad; acc(1); acc(2)];
end
