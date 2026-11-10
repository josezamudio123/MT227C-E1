function [K, info] = diseno_final()
%DISENO_FINAL  Ganancia adoptada como diseño final del grupo E1 (C1-C4, results.json, videos).
%   Decisión del grupo (2026-11-09), con la regla: "se cambia el diseño base solo si la mejora del
%   costo oficial promedio es estadísticamente significativa en semillas independientes".
%   Resultado de E1.5 (e1_5b_saa.m): ningún LQR factible la cumple (óptimo SAA: Jrel = 0.9994 ± 0.0225,
%   t = 0.12, semillas 101-120), por lo que se adopta el diseño base K0 (Q0, R0).
d = diseno_base_qube();
K = d.K0;
info.nombre = 'Diseño base K0 (Q0, R0), adoptado tras E1.5';
info.Q = d.Q0; info.R = d.R0;
info.polos = eig(d.A - d.B*K);
end
