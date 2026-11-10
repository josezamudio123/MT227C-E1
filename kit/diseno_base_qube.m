function d = diseno_base_qube(archivo)
%DISENO_BASE_QUBE Diseño base común: K0, P0 (LQR continuo con Q0, R0) y
%   filtro de Kalman base de ganancia estacionaria (Ad, Bd, Qd, Rd, L0, Sigma0).
%   Los valores se leen de diseno_base_ref.json. Si está disponible lqr
%   (Control System Toolbox), K0 se recalcula y se compara.
if nargin < 1, archivo = fullfile(fileparts(mfilename('fullpath')), 'diseno_base_ref.json'); end
txt = fileread(archivo);
r = jsondecode(txt);
campos = {'A','B','Q0','R0','K0','P0','Ad','Bd','Qd','Rd','C','L0','Sigma0'};
for i = 1:numel(campos)
    d.(campos{i}) = r.(campos{i});
end
d.K0 = reshape(d.K0, 1, []);
d.B  = reshape(d.B, [], 1); d.Bd = reshape(d.Bd, [], 1);
if exist('lqr', 'file') == 2 || exist('lqr', 'builtin') == 5
    K = lqr(d.A, d.B, d.Q0, d.R0);
    if norm(K - d.K0)/norm(d.K0) > 1e-8
        warning('diseno_base_qube: K0 recalculado difiere del de referencia.');
    end
end
end
