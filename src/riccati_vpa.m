function [P, paso] = riccati_vpa(A, B, Q, R, P_ini, ndig, nit)
%RICCATI_VPA  Referencia en precisión extendida (Symbolic Math Toolbox, vpa).
%   Newton-Kleinman en aritmética de ndig dígitos, partiendo de una solución en
%   doble precisión (P_ini, p. ej. de icare). Como Newton converge cuadráticamente,
%   pocas iteraciones dan todos los dígitos de doble precisión correctos.
%   Los datos se convierten EXACTAMENTE con sym(X, 'f') (sin aproximación racional),
%   de modo que la referencia es la solución exacta del mismo problema en doble.
%   paso: norma relativa de la última corrección (debe ser << 1e-16).
if nargin < 6 || isempty(ndig), ndig = 40; end
if nargin < 7 || isempty(nit),  nit = 6;   end
dig_ant = digits; digits(ndig); limpia = onCleanup(@() digits(dig_ant));
n  = size(A, 1);
As = vpa(sym(A, 'f')); Bs = vpa(sym(B, 'f')); Qs = vpa(sym(Q, 'f')); Rs = vpa(sym(R, 'f'));
Ps = vpa(sym((P_ini + P_ini')/2, 'f'));
I  = vpa(eye(n));
for k = 1:nit
    Ks = Rs \ (Bs.'*Ps);
    Ac = As - Bs*Ks;
    C  = Qs + Ks.'*Rs*Ks;
    M  = kron_sym(I, Ac.') + kron_sym(Ac.', I);       % vec(Ac' X + X Ac) = M vec(X)
    Pn = reshape(-(M \ C(:)), n, n);
    Pn = (Pn + Pn.')/2;
    paso = double(norm(Pn - Ps, 'fro') / norm(Pn, 'fro'));
    Ps = Pn;
end
P = double(Ps);
end

function K = kron_sym(X, Y)
% Producto de Kronecker para matrices sym.
[mx, nx] = size(X); [my, ny] = size(Y);
K = sym(zeros(mx*my, nx*ny));
for i = 1:mx
    for j = 1:nx
        K((i-1)*my+1:i*my, (j-1)*ny+1:j*ny) = X(i,j)*Y;
    end
end
end
