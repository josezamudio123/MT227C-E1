function r = residuo_riccati(A, B, Q, R, P)
%RESIDUO_RICCATI  Residuo relativo normalizado de la ecuación algebraica de Riccati.
%   r = ||A'P + PA - P S P + Q|| / (||A'P|| + ||PA|| + ||P S P|| + ||Q||),  S = B R^-1 B'
S = B/R*B';
Res = A'*P + P*A - P*S*P + Q;
r = norm(Res, 'fro') / (norm(A'*P, 'fro') + norm(P*A, 'fro') + norm(P*S*P, 'fro') + norm(Q, 'fro'));
end
