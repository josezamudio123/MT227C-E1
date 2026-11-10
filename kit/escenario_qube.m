function esc = escenario_qube(nombre, i, p)
%ESCENARIO_QUBE Definición de los escenarios comunes C1, C2, C3, C3b, C4 y C5.
%   esc = escenario_qube('C1')
%   esc = escenario_qube('C4', i)   planta i (1..200) del Monte Carlo, reproducible
%   Campos: nombre, x0, T, I_imp [N m s], t_imp [s], t0 (inicio de métricas), p (planta)
%   En C4 además: factores (multiplicadores de mp, Lp, Rm, kt) y semilla_planta.
if nargin < 3, p = parametros_qube(); end
if nargin < 2 || isempty(i), i = 1; end
esc.nombre = nombre; esc.I_imp = 0; esc.t_imp = 1; esc.t0 = 0; esc.T = 5;
esc.x0 = [0; 0.05; 0; 0];
switch upper(nombre)
    case 'C1'
    case 'C2'
        esc.x0 = [0; 0.35; 0; 0];
    case 'C3'
        esc.x0 = zeros(4,1); esc.I_imp = 6e-4; esc.t0 = 1;
    case 'C3B'
        esc.nombre = 'C3b'; esc.x0 = zeros(4,1); esc.I_imp = 2e-3; esc.t0 = 1;
    case 'C4'
        % Plantas perturbadas: mp, Lp, Rm, kt uniformes en +-20 %; km = kt (SI).
        rng(1000 + i, 'twister');                  % semilla de la planta i
        f = 0.8 + 0.4*rand(1, 4);
        esc.factores = f;                           % [mp Lp Rm kt] relativos al nominal
        esc.semilla_planta = 1000 + i;
        p = parametros_qube('mp', p.mp*f(1), 'Lp', p.Lp*f(2), 'Rm', p.Rm*f(3), ...
                            'kt', p.kt*f(4), 'km', p.kt*f(4));
        esc.nombre = sprintf('C4_%03d', i);
    case 'C5'
        esc.x0 = [0; pi; 0; 0]; esc.T = 10;
    otherwise
        error('escenario_qube: escenario desconocido %s', nombre);
end
esc.p = p;
end
