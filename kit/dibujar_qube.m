function dibujar_qube(hBrazo, hPend, hMasa, theta, alpha, p)
%DIBUJAR_QUBE Actualiza los objetos gráficos con los ángulos dados (ver geometria_qube).
[P0, P1, P2] = geometria_qube(theta, alpha, p);
set(hBrazo, 'XData', [P0(1) P1(1)], 'YData', [P0(2) P1(2)], 'ZData', [P0(3) P1(3)]);
set(hPend,  'XData', [P1(1) P2(1)], 'YData', [P1(2) P2(2)], 'ZData', [P1(3) P2(3)]);
set(hMasa,  'XData', P2(1), 'YData', P2(2), 'ZData', P2(3));
end
