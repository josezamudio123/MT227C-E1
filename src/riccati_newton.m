function [P, K, hist] = riccati_newton(A, B, Q, R, K_ini, tol, maxit)
%RICCATI_NEWTON  Método (c): Newton-Kleinman (Kleinman, 1968).
%   Parte de una ganancia K_ini ESTABILIZANTE y repite:
%     1) Ak = A - B K
%     2) Resolver la ecuación de Lyapunov  Ak' P + P Ak + Q + K' R K = 0
%     3) K = R^-1 B' P
%   Si K_ini estabiliza, todas las iteraciones estabilizan y la convergencia
%   es cuadrática cerca de la solución.
%   hist: tabla por iteración con residuo normalizado y cambio de K.
%   Parada: cambio relativo de K < tol, o estancamiento del residuo en el
%   nivel de redondeo (residuo < 1e-8 y sin mejorar respecto de la iteración anterior).
%   hist(k).P guarda la iterada (para estudiar la convergencia frente a una referencia).
if nargin < 6 || isempty(tol),   tol = 1e-12; end
if nargin < 7 || isempty(maxit), maxit = 50;  end
if max(real(eig(A - B*K_ini))) >= 0
    error('riccati_newton: la ganancia inicial no es estabilizante.');
end
K = K_ini;
hist = struct('k', {}, 'residuo', {}, 'dK', {}, 'P', {});
for k = 1:maxit
    Ak = A - B*K;
    P  = lyap_kron(Ak', Q + K'*R*K);            % Ak'P + P Ak + (Q + K'RK) = 0
    P  = (P + P')/2;
    Kn = R \ (B'*P);
    dK = norm(Kn - K) / norm(Kn);
    hist(k).k = k;
    hist(k).residuo = residuo_riccati(A, B, Q, R, P);
    hist(k).dK = dK;
    hist(k).P = P;
    K = Kn;
    if dK < tol, break; end
    if k > 1 && hist(k).residuo < 1e-8 && hist(k).residuo >= hist(k-1).residuo, break; end
end
end
