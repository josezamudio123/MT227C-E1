%E1_5C_SENSIBILIDAD  Inciso E1.5 (comprobación): ¿cuánto cambia el costo oficial ante una
%   perturbación ÍNFIMA de la ganancia?
%
%   Observación: en e1_5b_saa el diseño base recalculado con icare (difiere de K0 en ~1e-14)
%   dio Jrel = 0.9991 ± 0.0021 en vez de 1 exacto.
%   Hipótesis: la cuantización de los encoders (redondeo a cuentas enteras) hace que un cambio
%   minúsculo en K cambie, en algún instante, la cuenta medida; desde ahí la trayectoria se
%   separa. Entonces el costo oficial tiene un "piso de ruido" aunque la semilla sea la misma.
%   Prueba: K = K0*(1 + delta) con delta = 0, 1e-15, 1e-12, 1e-9, 1e-6, en el simulador
%   oficial (con cuantización) y en el ideal (estado real, sin cuantización ni ruido).
%   Si la hipótesis es correcta: con cuantización, el cambio de J es del orden de 0.1-1 %
%   incluso para delta = 1e-15; en el ideal, el cambio es proporcional a delta.

clear; clc;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'kit'), fullfile(raiz, 'src'));
d = diseno_base_qube(); est = estimador_base(d);
esc = {'C1', 'C2', 'C3', 'C3b'};
deltas = [0 1e-15 1e-12 1e-9 1e-6];
modos = {struct('semilla', 1), struct('ideal', true)}; nom = {'oficial (cuantización + ruido, semilla 1)', 'ideal (sin cuantización ni ruido)'};
for mo = 1:2
    J = zeros(numel(deltas), 4);
    for i = 1:numel(deltas)
        ctrl = controlador_lineal(d.K0*(1 + deltas(i)));
        for c = 1:4
            m = metricas_qube(simular_qube(ctrl, est, escenario_qube(esc{c}), modos{mo}));
            J(i,c) = m.J;
        end
    end
    dJ{mo} = abs(J - J(1,:))./J(1,:); %#ok<SAGROW>
    fprintf('=== Simulador %s ===\n', nom{mo});
    fprintf('%8s | %12s %12s %12s %12s   (cambio relativo de J frente a delta = 0)\n', 'delta', esc{:});
    for i = 1:numel(deltas)
        fprintf('%8.0e | %12.2e %12.2e %12.2e %12.2e\n', deltas(i), abs(J(i,:) - J(1,:))./J(1,:));
    end
    fprintf('\n');
end
fprintf('Diferencia entre K de icare (Q0, R0) y K0 del kit: %.1e (relativa)\n', ...
        norm(d.R0\(d.B'*icare(d.A, d.B, d.Q0, d.R0)) - d.K0)/norm(d.K0));

% Números citados en el informe: anotar -> results.json -> informe/valores_E1.tex
anotar('e15c_piso_C1', dJ{1}(2,1), 'p2'); anotar('e15c_piso_C2', dJ{1}(2,2), 'p2');
anotar('e15c_piso_C3', dJ{1}(2,3), 'p1'); anotar('e15c_piso_C3b', dJ{1}(2,4), 'p2');
anotar('e15c_piso_ideal_max', max(dJ{2}(2,:)), 'e0');
