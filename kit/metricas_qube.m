function m = metricas_qube(log)
%METRICAS_QUBE Métricas del Anexo B de la guía a partir de un registro de simular_qube.
%   Muestras t_0..t_N (incluida la última) y entrada u_k constante en [t_k, t_{k+1}).
%   Ventana de evaluación: t_k >= t0, con t0 = 0 (C1, C2, C4), t0 = t_imp (C3, C3b)
%   o t0 = t_lev (C5, primer instante con |alpha envuelto| < 0.3 rad).
%   Costo: J = trapz(x'Q0x) sobre las muestras de la ventana + R0*Ts*sum(u_k^2) (exacto con ZOH).
%   ts: tiempo, medido desde t0, a partir del cual |alpha| <= 0.02 rad en todas las muestras
%       restantes; 0 si nunca sale de la banda; [] (null) si la última muestra está fuera.
%   éxito: |theta| <= theta_max en todas las muestras (incluida la última) y, al final,
%          |alpha| < 0.02 rad y |dalpha| < 0.2 rad/s.
p = log.esc.p; Ts = p.Ts; t = log.t; X = log.x; N = numel(log.u);
Q0 = diag([1/(pi/4)^2, 1/(pi/36)^2, 0, 0]); R0 = 1/10^2;
al = atan2(sin(X(:,2)), cos(X(:,2)));          % alpha envuelto en (-pi, pi]
m.escenario = log.esc.nombre;
m.max_uc = max(abs(log.uc));
m.max_u  = max(abs(log.u));
m.frac_sat = mean(abs(log.uc) > p.Vmax);
m.max_theta = max(abs(X(:,1)));
viol = abs(X(:,1)) > p.theta_max;              % incluye la última muestra
m.violacion_duracion = sum(viol)*Ts;
m.violacion_magnitud = max([0; abs(X(viol,1)) - p.theta_max]);
m.exito = ~any(viol) && abs(al(end)) < 0.02 && abs(X(end,4)) < 0.2;
t0 = log.esc.t0;
if strcmpi(log.esc.nombre, 'C5')
    m.energia = Ts*sum(log.u.^2);
    i_lev = find(abs(al) < 0.3, 1);
    if isempty(i_lev), m.t_levantamiento = []; t0 = inf;
    else, m.t_levantamiento = t(i_lev); t0 = t(i_lev); end
end
w = find(t >= t0 - 1e-12);                     % muestras de la ventana
if numel(w) >= 2
    Xw = X(w,:); Xw(:,2) = al(w);
    wu = w(w <= N);                            % intervalos [t_k, t_{k+1}) dentro de la ventana
    m.J = trapz(t(w), sum((Xw*Q0).*Xw, 2)) + R0*Ts*sum(log.u(wu).^2);
    fuera = find(abs(al(w)) > 0.02);
    if isempty(fuera)
        m.ts = 0;
    elseif fuera(end) == numel(w)
        m.ts = [];                             % no se establece dentro del horizonte
    else
        m.ts = t(w(fuera(end) + 1)) - t0;
    end
else
    m.J = []; m.ts = [];
end
if m.exito, m.estado = 'ok'; else, m.estado = 'fallo'; end
if ~log.opts.ideal
    e = log.xh - X(1:N,:);
    m.rmse_alpha = sqrt(mean(e(:,2).^2));
    m.rmse_dalpha = sqrt(mean(e(:,4).^2));
end
end
