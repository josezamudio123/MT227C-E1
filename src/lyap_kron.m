function X = lyap_kron(F, C)
%LYAP_KRON  Resuelve F X + X F' + C = 0 por producto de Kronecker (sin toolboxes).
%   vec(F X + X F') = (I kron F + F kron I) vec(X).
%   Útil para n pequeño (n = 4 -> sistema de 16 x 16).
n = size(F, 1);
I = eye(n);
X = reshape(-(kron(I, F) + kron(F, I)) \ C(:), n, n);
end
