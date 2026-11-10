function [P0, P1, P2] = geometria_qube(theta, alpha, p)
%GEOMETRIA_QUBE Posiciones 3D del pivote del brazo (P0), del extremo del brazo
%   (P1) y del extremo del péndulo (P2) para ángulos dados.
%   El brazo gira en el plano horizontal z = 0. alpha = 0: péndulo vertical hacia
%   arriba (z > 0); alpha = pi: hacia abajo (z < 0). Con la regla de signos de la
%   guía, alpha > 0 inclina el péndulo hacia atrás respecto del avance del brazo
%   (sentido de theta creciente), que es la reacción física a una aceleración del brazo.
P0 = [0; 0; 0];
P1 = p.r*[cos(theta); sin(theta); 0];
tg = [-sin(theta); cos(theta); 0];          % dirección de avance del brazo
P2 = P1 + p.Lp*(-sin(alpha)*tg + cos(alpha)*[0; 0; 1]);
end
