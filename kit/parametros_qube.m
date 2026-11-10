function p = parametros_qube(varargin)
%PARAMETROS_QUBE Parámetros de la planta de referencia (QUBE-Servo 2) y del benchmark.
%   p = parametros_qube()                 valores nominales
%   p = parametros_qube('mp',0.026,...)   reemplaza parámetros base y recalcula los derivados
%   Fuente: Manual QUBE-Servo 2 (Quanser, 2016), Tabla 2.2; ver guía, sección 2.2.
p.Rm = 8.4;        % [ohm]
p.Lm = 1.16e-3;    % [H]
p.kt = 0.042;      % [N m/A]
p.km = 0.042;      % [V s/rad]
p.Jm = 4.0e-6;     % [kg m^2] rotor
p.Jh = 0.6e-6;     % [kg m^2] cubo
p.mr = 0.095;      % [kg]  brazo
p.r  = 0.085;      % [m]
p.mp = 0.024;      % [kg]  péndulo
p.Lp = 0.129;      % [m]
p.Dr = 0.0015;     % [N m s/rad] supuesto de modelo
p.Dp = 0.0005;     % [N m s/rad] supuesto de modelo
p.g  = 9.81;       % [m/s^2]
p.N  = 2048;       % [cuentas/rev]
p.Vmax = 10;       % [V]   decisión del curso
p.Ts = 2e-3;       % [s]   decisión del curso
p.theta_max = pi/2;% [rad] decisión del curso
p.S_tau = 1e-8;    % [N^2 m^2 s] ruido base de par sobre el brazo
for i = 1:2:numel(varargin)
    p.(varargin{i}) = varargin{i+1};
end
p = derivados(p);
end

function p = derivados(p)
p.lp = p.Lp/2;                              % convención: varilla uniforme
p.Jr = p.Jm + p.Jh + p.mr*p.r^2/3;          % brazo respecto del pivote (convención)
p.Jp = p.mp*p.Lp^2/3;                       % péndulo respecto del pivote (convención)
p.q  = 2*pi/p.N;                            % paso de cuantización [rad]
end
