function [Lop, sep, nLinv] = operador_lyapunov(Ac)
%OPERADOR_LYAPUNOV  Operador de Lyapunov del lazo cerrado como matriz (Kronecker).
%   L(X) = Ac' X + X Ac   <=>   vec(L(X)) = Lop * vec(X),  Lop = I kron Ac' + Ac' kron I
%   Sus autovalores son lambda_i + lambda_j (lambda = autovalores de Ac).
%   sep   = sigma_min(Lop) = 1/||L^-1||_2 : distancia del operador a ser singular.
%   nLinv = ||L^-1||_2 : cuánto puede amplificar un residuo hasta convertirse en error de P.
n = size(Ac, 1);
I = eye(n);
Lop = kron(I, Ac') + kron(Ac', I);
s = svd(Lop);
sep = s(end);
nLinv = 1/sep;
end
