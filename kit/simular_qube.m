function log = simular_qube(ctrl, est, esc, opts)
%SIMULAR_QUBE Simulador oficial del benchmark (planta no lineal + lazo digital).
%   log = simular_qube(ctrl, est, esc, opts)
%   ctrl : controlador (ver controlador_lineal)
%   est  : estimador (ver estimador_base); se ignora si opts.ideal = true
%   esc  : escenario (ver escenario_qube)
%   opts : estructura opcional
%     .ideal    = false  true: estado real, sin ruido ni cuantización
%     .semilla  = 1      semilla del ruido de proceso
%     .retardo  = 0      retardo de la acción de control en muestras (0 o 1)
%     .nsub     = 4      subpasos RK4 por periodo (paso = Ts/nsub)
%     .ruido    = true   ruido de par (solo si ideal = false)
%   Secuencia en cada periodo k: medir y cuantizar y; actualizar el estimador;
%   calcular u_c; saturar; aplicar u constante durante Ts.
if nargin < 4, opts = struct(); end
op = struct('ideal', false, 'semilla', 1, 'retardo', 0, 'nsub', 4, 'ruido', true);
fn = fieldnames(opts); for j = 1:numel(fn), op.(fn{j}) = opts.(fn{j}); end
p = esc.p; Ts = p.Ts; h = Ts/op.nsub; Nk = round(esc.T/Ts);
rng(op.semilla, 'twister');
x = esc.x0(:);
X = zeros(Nk+1, 4); X(1,:) = x';
XH = zeros(Nk, 4); UC = zeros(Nk, 1); U = zeros(Nk, 1);
kimp = -1; if esc.I_imp ~= 0, kimp = round(esc.t_imp/Ts); end
imp = [];
mem_c = ctrl.mem; u_ant = 0; u_cola = 0;
for k = 0:Nk-1
    if k == kimp                                   % impulso: salto de velocidades en t_imp
        x_antes = x;
        x(3:4) = x(3:4) + masa_qube(x(2), p) \ [esc.I_imp; 0];
        X(k+1,:) = x';                             % el registro guarda el estado en t_imp^+
        imp = struct('k', k, 't', k*Ts, 'x_antes', x_antes', 'x_despues', x');
    end
    if op.ideal
        xh = x;
    else
        y = p.q*round(x(1:2)/p.q);                 % encoders cuantizados
        if k == 0
            [xh, mem_e] = est.inicio(y);
        else
            [xh, mem_e] = est.actualizar(xh, y, u_ant, mem_e);
        end
    end
    [uc, mem_c] = ctrl.ley(xh, k*Ts, mem_c);
    u_calc = min(max(uc, -p.Vmax), p.Vmax);
    if op.retardo == 1
        u = u_cola; u_cola = u_calc;              % se aplica la del periodo anterior
    else
        u = u_calc;
    end
    for j = 1:op.nsub                              % RK4 con u constante (ZOH)
        td = 0;
        if ~op.ideal && op.ruido, td = sqrt(p.S_tau/h)*randn(); end
        k1 = modelo_qube(x, u, p, td);
        k2 = modelo_qube(x + h/2*k1, u, p, td);
        k3 = modelo_qube(x + h/2*k2, u, p, td);
        k4 = modelo_qube(x + h*k3, u, p, td);
        x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
    end
    u_ant = u;
    X(k+2,:) = x'; XH(k+1,:) = xh'; UC(k+1) = uc; U(k+1) = u;
end
log.t  = (0:Nk)'*Ts;      % instantes de muestreo t_0..t_Nk (Nk+1 valores)
log.x  = X;               % estado real en t_0..t_Nk (incluida la última muestra)
log.xh = XH;              % estimado usado por el controlador en t_0..t_{Nk-1} (Nk)
log.uc = UC;              % control calculado antes de saturar en t_0..t_{Nk-1} (Nk)
log.u  = U;               % control aplicado, constante en [t_k, t_{k+1}) (Nk)
log.impulso = imp;        % instante y salto aplicado (vacío si no hay impulso)
log.esc = esc; log.opts = op;
end
