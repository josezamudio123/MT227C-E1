function P = riccati_schur(A, B, Q, R, opcion)
%RICCATI_SCHUR  Método (b): forma real de Schur ordenada de la Hamiltoniana (Laub, 1979).
%   Igual que el método (a), pero en vez de vectores propios (que pueden estar mal
%   condicionados) usa una base ORTONORMAL del subespacio estable: H*U = U*T, con
%   T casi triangular y los autovalores estables primero (ordschur 'lhp').
%   P = U21 * inv(U11).
%   opcion = 'balance': antes de schur se balancea H con una semejanza diagonal
%   (balance de MATLAB, como hace eig por defecto): Hb = Tb\H*Tb. El subespacio estable
%   de H es Tb * (subespacio estable de Hb), y cualquier base de él sirve para P = X2/X1.
if nargin < 5, opcion = 'nobalance'; end
n = size(A, 1);
H = [A, -B/R*B'; -Q, -A'];
if strcmp(opcion, 'balance')
    [Tb, Hb] = balance(H);
else
    Tb = eye(2*n); Hb = H;
end
[U, T] = schur(Hb, 'real');
[U, ~] = ordschur(U, T, 'lhp');
X = Tb*U(:, 1:n);
P = X(n+1:end, :) / X(1:n, :);
end
