function P = riccati_pencil(A, B, Q, R)
%RICCATI_PENCIL  Ecuación de Riccati por el haz (pencil) extendido de Arnold y Laub (1984),
%   la formulación que usan care/icare. NO forma S = B R^-1 B' ni invierte R.
%
%   Haz extendido de dimensión 2n+m:  M v = lambda N v, con
%       M = [ A   0   B ]      N = [ I 0 0 ]      v = [x; y; u]
%           [-Q  -A'  0 ]          [ 0 I 0 ]
%           [ 0   B'  R ]          [ 0 0 0 ]
%   (la tercera fila es la condición de optimalidad B'y + R u = 0, sin despejar u).
%   1) Compresión: QR de la columna [B; 0; R] y proyección sobre su complemento
%      ortogonal -> haz de 2n x 2n con los mismos autovalores finitos que H.
%   2) QZ real ordenada (autovalores estables primero) -> base [V1; V2] del
%      subespacio deflactante estable -> P = V2 / V1.
n = size(A, 1); m = size(B, 2);
M = [A, zeros(n), B; -Q, -A', zeros(n, m); zeros(m, n), B', R];
N = blkdiag(eye(2*n), zeros(m));
[Qc, ~] = qr([B; zeros(n, m); R]);         % columna que se elimina
Z = Qc(:, m+1:end);                         % complemento ortogonal (2n+m) x 2n
Mt = Z' * M(:, 1:2*n);
Nt = Z' * N(:, 1:2*n);
[AA, BB, Qz, Zz] = qz(Mt, Nt, 'real');
[~, ~, ~, Zs] = ordqz(AA, BB, Qz, Zz, 'lhp');
V = Zs(:, 1:n);
P = V(n+1:end, :) / V(1:n, :);
P = (P + P')/2;
end
