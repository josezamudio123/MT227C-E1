function M = masa_qube(alpha, p)
%MASA_QUBE Matriz de masa M(alpha) del modelo no lineal (alpha = 0 arriba).
M = [p.Jr + p.mp*p.r^2 + p.Jp*sin(alpha)^2, -p.mp*p.r*p.lp*cos(alpha);
     -p.mp*p.r*p.lp*cos(alpha),             p.Jp];
end
