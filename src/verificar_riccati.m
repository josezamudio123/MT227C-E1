function v = verificar_riccati(A, B, Q, R, P)
%VERIFICAR_RICCATI  Las cuatro comprobaciones de E1.2 para una solución P.
%   residuo   : residuo relativo normalizado
%   asimetria : ||P - P'|| / ||P||
%   min_eig_P : menor autovalor de (P+P')/2 (debe ser >= 0: semidefinida positiva)
%   max_re_cl : mayor parte real de eig(A - B K) (debe ser < 0: Hurwitz)
K = R \ (B'*P);
v.residuo   = residuo_riccati(A, B, Q, R, P);
v.asimetria = norm(P - P', 'fro') / norm(P, 'fro');
v.min_eig_P = min(eig((P + P')/2));
v.max_re_cl = max(real(eig(A - B*K)));
v.ok = v.residuo < 1e-10 && v.asimetria < 1e-10 && v.min_eig_P > -1e-10*norm(P) && v.max_re_cl < 0;
end
