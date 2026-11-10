function P = riccati_hamiltoniano(A, B, Q, R, opcion)
%RICCATI_HAMILTONIANO  Método (a): vectores propios de la matriz Hamiltoniana (Potter, 1966).
%   Resuelve A'P + PA - P B R^-1 B' P + Q = 0.
%   1) H = [A  -B R^-1 B';  -Q  -A'] tiene 2n autovalores simétricos (+lambda, -lambda).
%   2) Se toman los n vectores propios de autovalores con parte real negativa: [X1; X2].
%   3) P = X2 * inv(X1).
%   opcion = 'nobalance': eig SIN el balanceo que MATLAB aplica por defecto (para E1.3).
if nargin < 5, opcion = 'balance'; end
n = size(A, 1);
H = [A, -B/R*B'; -Q, -A'];
[V, D] = eig(H, opcion);
idx = real(diag(D)) < 0;
if nnz(idx) ~= n
    error('riccati_hamiltoniano: hay autovalores sobre el eje imaginario (%d estables de %d).', nnz(idx), n);
end
X = V(:, idx);
P = real(X(n+1:end, :) / X(1:n, :));
end
