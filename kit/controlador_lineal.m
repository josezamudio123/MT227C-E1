function ctrl = controlador_lineal(K)
%CONTROLADOR_LINEAL Controlador u_c = -K*xhat con la interfaz del simulador.
%   Interfaz general de un controlador:
%     ctrl.ley = @(xhat, t, mem) -> [u_c, mem]   (mem: memoria interna libre)
%     ctrl.mem = valor inicial de la memoria
K = reshape(K, 1, []);
ctrl.ley = @(xh, t, mem) deal(-K*xh, mem);
ctrl.mem = [];
end
