function K = ganancia_bass(A, B, beta)
%GANANCIA_BASS  Ganancia estabilizante inicial por el método de Bass (sin Riccati).
%   Con beta > max(-real(eig(A))), se resuelve
%       (A + beta I) Z + Z (A + beta I)' = 2 B B'
%   y K = B' Z^-1 coloca todos los polos de A - B K con parte real < -beta.
%   Requiere (A, B) controlable (Z > 0).
n = size(A, 1);
Ab = A + beta*eye(n);
Z = lyap_kron(-Ab, 2*(B*B'));       % -Ab Z - Z Ab' + 2BB' = 0  <=>  Ab Z + Z Ab' = 2BB'
K = B' / Z;
end
