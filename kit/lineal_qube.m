function [A, B, A5, B5, Gw] = lineal_qube(p)
%LINEAL_QUBE Modelo linealizado en el equilibrio superior (alpha = 0).
%   [A,B]          modelo de 4 estados (x = [theta alpha dtheta dalpha]')
%   [A5,B5]        modelo de 5 estados con corriente de armadura
%   Gw             canal de la perturbación de par sobre el brazo
Mi = inv(masa_qube(0, p));
A = zeros(4); A(1,3) = 1; A(2,4) = 1;
T = [0 0 -p.Dr - p.kt*p.km/p.Rm 0; 0 p.mp*p.g*p.lp 0 -p.Dp];
A(3:4,:) = Mi*T;
B = [0; 0; Mi*[p.kt/p.Rm; 0]];
A5 = zeros(5); A5(1,3) = 1; A5(2,4) = 1;
T5 = [0 0 -p.Dr 0 p.kt; 0 p.mp*p.g*p.lp 0 -p.Dp 0];
A5(3:4,:) = Mi*T5;
A5(5,3) = -p.km/p.Lm; A5(5,5) = -p.Rm/p.Lm;
B5 = [0; 0; 0; 0; 1/p.Lm];
Gw = [0; 0; Mi*[1; 0]];
end
