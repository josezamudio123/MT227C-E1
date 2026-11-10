function idx = cuadros_qube(t, dt_cuadro)
%CUADROS_QUBE Índices del registro que se dibujan en la animación: los instantes de muestreo
%   más cercanos a una rejilla uniforme de paso dt_cuadro. Incluye siempre el primero y el último.
tc = t(1):dt_cuadro:t(end);
if isempty(tc) || tc(end) < t(end), tc(end+1) = t(end); end
idx = zeros(1, numel(tc));
for i = 1:numel(tc), [~, idx(i)] = min(abs(t - tc(i))); end
idx = unique(idx);                 % unique ordena; los índices ya son crecientes
end
