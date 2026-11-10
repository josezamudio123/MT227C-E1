function [As, Bs, Qs, Rs, deshacer] = escalar_riccati(A, B, Q, R, nivel)
%ESCALAR_RICCATI  Transformaciones EXACTAS del problema LQR que no cambian su solución
%   física, solo el tamaño de los números (para E1.3). Devuelve el problema escalado y
%   una función deshacer(Ps) que recupera P en las unidades originales.
%   nivel 0: sin cambios.
%   nivel 1: + normalización de la entrada  u = R^(-1/2) v  ->  B <- B R^(-1/2), R <- I.
%            (no cambia S = B R^-1 B', pero sí los bloques B y R del haz extendido)
%   nivel 2: + escalado diagonal de estados x = D z, D de balance(A,'noperm')
%            ->  A <- D\A*D,  B <- D\B,  Q <- D'*Q*D,  P = D'\Pz/D
%   nivel 3: + escalado escalar x = t z que iguala ||S|| y ||Q||:
%            t = (||S||/||Q||)^(1/4)  ->  B <- B/t,  Q <- t^2 Q,  P = Pz/t^2
n = size(A, 1);
As = A; Bs = B; Qs = Q; Rs = R; D = eye(n); t = 1;
if nivel >= 1
    L = chol(R, 'lower');                 % R = L L'
    Bs = Bs / L';  Rs = eye(size(R));
end
if nivel >= 2
    [D, ~] = balance(As, 'noperm');       % D diagonal
    As = D\As*D;  Bs = D\Bs;  Qs = D'*Qs*D;
end
if nivel >= 3
    t = (norm(Bs*Bs', 'fro') / max(norm(Qs, 'fro'), realmin))^(1/4);
    Bs = Bs/t;  Qs = t^2*Qs;
end
deshacer = @(Pz) (D')\(Pz/t^2)/D;
end
