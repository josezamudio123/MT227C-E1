function [hBrazo, hPend, hMasa] = escena_qube(ax, p, colorBrazo, colorPend)
%ESCENA_QUBE Prepara los ejes 3D y crea los objetos gráficos del brazo y del péndulo.
%   Los límites contienen el péndulo hacia arriba y hacia abajo (|z| <= Lp).
hold(ax, 'on'); grid(ax, 'on');
L = p.r + p.Lp;
plot3(ax, [0 0], [0 0], [-1.15*p.Lp 0], '-', 'Color', [0.1 0.1 0.1], 'LineWidth', 7);  % cuerpo del motor
th = linspace(0, 2*pi, 60);
plot3(ax, p.r*cos(th), p.r*sin(th), zeros(size(th)), ':', 'Color', [0.6 0.6 0.6]);    % recorrido del brazo
hBrazo = plot3(ax, [0 p.r], [0 0], [0 0], '-', 'Color', colorBrazo, 'LineWidth', 5);
hPend  = plot3(ax, [p.r p.r], [0 0], [0 p.Lp], '-', 'Color', colorPend, 'LineWidth', 3);
hMasa  = plot3(ax, p.r, 0, p.Lp, 'o', 'Color', colorPend, 'MarkerFaceColor', colorPend, 'MarkerSize', 6);
axis(ax, 'equal');
axis(ax, [-L L -L L -1.15*p.Lp 1.15*p.Lp]);
view(ax, 35, 22);
xlabel(ax, 'x [m]'); ylabel(ax, 'y [m]'); zlabel(ax, 'z [m]');
end
