function est = estimador_base(d)
%ESTIMADOR_BASE Filtro de Kalman discreto de ganancia estacionaria L0.
%   Interfaz general de un estimador:
%     est.inicio     = @(y0)                  -> [xhat, mem]
%     est.actualizar = @(xhat, y, u_ant, mem) -> [xhat, mem]
%   y = [theta; alpha] cuantizadas; u_ant = tensión aplicada en el periodo anterior.
est.inicio = @(y0) deal([y0(:); 0; 0], []);
est.actualizar = @(xh, y, u_ant, mem) actualizar(xh, y, u_ant, mem, d);
end

function [xh, mem] = actualizar(xh, y, u_ant, mem, d)
xp = d.Ad*xh + d.Bd*u_ant;          % predicción
xh = xp + d.L0*(y(:) - d.C*xp);     % actualización
end
