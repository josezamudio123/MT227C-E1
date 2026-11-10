function [ok, errores] = validar_results(archivo, encargo)
%VALIDAR_RESULTS Validación automática de results.json (Anexo A de la guía).
%   [ok, errores] = validar_results('results.json', 'E1')
%
%   Qué comprueba: presencia de las claves obligatorias; que los valores obligatorios
%   no estén vacíos ni sean null; dimensiones de las matrices del modelo y del diseño base;
%   concordancia de A, B y K0 con el kit; estructura de cada escenario y su campo "estado";
%   métricas obligatorias según el estado; C5 solo para E4; métricas de E2 por filtro y condición.
%   Qué NO comprueba: la corrección científica de los resultados del encargo. Un archivo
%   válido solo indica que el formato es correcto y que el modelo coincide con el kit.
r = jsondecode(fileread(archivo));
encargo = upper(encargo);
errores = {};
% ---------- claves comunes ----------
comunes = {'grupo','software','semillas','A','B','eig_A','A5','B5','polo_electrico','K0','L_base'};
porEncargo.E1 = {'resid_care','K_opt','eig_cl_opt','rho_elipse','mc_region'};
porEncargo.E2 = {'Qd','Rd','L_propio','filtros'};
porEncargo.E3 = {'rho_lqr','rho_info','rho_lqg_mc','g_intervalo'};
porEncargo.E4 = {'J_energia_min','T_swingup','K_tvlqr_0','N_mpc','t_qp'};
porEncargo.E5 = {'Ts_critico_retardo','K_dare','K_qlearning','muestras_convergencia','costo_exploracion'};
if ~isfield(porEncargo, encargo), error('validar_results: encargo desconocido %s', encargo); end
obligatorias = [comunes, porEncargo.(encargo)];
% Ts_critico_retardo puede ser null con estado "no_encontrado" (ver guía, E5.2)
anulables = {'Ts_critico_retardo'};
for i = 1:numel(obligatorias)
    c = obligatorias{i};
    if ~isfield(r, c)
        errores{end+1} = sprintf('falta la clave "%s"', c);
    elseif isempty(r.(c)) && ~any(strcmp(c, anulables))
        errores{end+1} = sprintf('"%s" está vacío o es null', c);
    end
end
if isfield(r, 'Ts_critico_retardo') && isempty(r.Ts_critico_retardo) && ...
        ~(isfield(r, 'Ts_critico_retardo_estado') && strcmp(r.Ts_critico_retardo_estado, 'no_encontrado'))
    if strcmp(encargo, 'E5')
        errores{end+1} = '"Ts_critico_retardo" es null sin "Ts_critico_retardo_estado" = "no_encontrado"';
    end
end
% ---------- dimensiones y concordancia con el kit ----------
dims = {'A',[4 4]; 'B',[4 1]; 'A5',[5 5]; 'B5',[5 1]; 'K0',[1 4]; 'L_base',[4 2]; 'eig_A',[4 1]};
for i = 1:size(dims, 1)
    c = dims{i,1};
    if isfield(r, c) && ~isempty(r.(c))
        v = r.(c);
        if ~isnumeric(v) || ~isequal(sort(size(v)), sort(dims{i,2}))
            errores{end+1} = sprintf('"%s" debe ser numérico de %dx%d', c, dims{i,2}(1), dims{i,2}(2));
        end
    end
end
ref = diseno_base_qube();
comparar = {'A', ref.A; 'B', ref.B; 'K0', ref.K0};
for i = 1:size(comparar, 1)
    c = comparar{i,1}; w = comparar{i,2};
    if isfield(r, c) && isnumeric(r.(c)) && numel(r.(c)) == numel(w)
        v = reshape(r.(c), size(w));
        er = norm(v(:) - w(:))/norm(w(:));
        if er > 1e-4
            errores{end+1} = sprintf('"%s" difiere del kit (error relativo %.2e)', c, er);
        end
    end
end
% ---------- escenarios ----------
estados = {'ok','fallo','no_aplica','no_encontrado'};
metricasOK = {'J','ts','max_uc','max_u','frac_sat','max_theta','exito'};
metricasFallo = {'max_uc','max_u','max_theta','exito'};
escenarios = {'C1','C2','C3','C3b','C4','C5'};
for i = 1:numel(escenarios)
    e = escenarios{i};
    if ~isfield(r, e), errores{end+1} = sprintf('falta el escenario "%s"', e); continue; end
    s = r.(e);
    if ~isstruct(s) || ~isfield(s, 'estado') || ~any(strcmp(s.estado, estados))
        errores{end+1} = sprintf('%s: falta "estado" válido (%s)', e, strjoin(estados, ', '));
        continue;
    end
    if strcmp(e, 'C5')
        if strcmp(encargo, 'E4')
            if strcmp(s.estado, 'ok')
                % levantamiento logrado: t_levantamiento debe tener valor
                errores = exigir(errores, s, [metricasOK, {'t_levantamiento','energia'}], 'C5');
            elseif strcmp(s.estado, 'fallo')
                % si el péndulo nunca se levantó, t_levantamiento, J y ts pueden ser null
                errores = exigir(errores, s, [metricasFallo, {'energia'}], 'C5');
                if ~isfield(s, 't_levantamiento')
                    errores{end+1} = 'C5: falta "t_levantamiento" (use null si el péndulo no se levantó)';
                end
            else
                errores{end+1} = 'C5: en E4 el estado debe ser "ok" o "fallo"';
            end
        elseif ~strcmp(s.estado, 'no_aplica')
            errores{end+1} = 'C5: solo se exige a E4; para este encargo use "estado": "no_aplica"';
        end
        continue;
    end
    if strcmp(e, 'C4')
        errores = exigir(errores, s, {'n','n_exito','tasa_exito'}, 'C4');
        continue;
    end
    if strcmp(s.estado, 'ok')
        errores = exigir(errores, s, metricasOK, e);
    elseif strcmp(s.estado, 'fallo')
        errores = exigir(errores, s, metricasFallo, e);
    else
        errores{end+1} = sprintf('%s: escenario obligatorio; el estado debe ser "ok" o "fallo"', e);
    end
end
% ---------- E2: métricas por filtro y condición ----------
if strcmp(encargo, 'E2') && isfield(r, 'filtros') && ~isempty(r.filtros)
    campos = {'filtro','condicion','M','nees','nis','tasa_rechazo','denominador','rmse_alpha','rmse_dalpha'};
    f = r.filtros;
    if ~isstruct(f)
        errores{end+1} = '"filtros" debe ser una lista de objetos con campos homogéneos';
    else
        for k = 1:numel(f)
            errores = exigir(errores, f(k), campos, sprintf('filtros(%d)', k));
        end
    end
end
ok = isempty(errores);
if ok
    fprintf('results.json válido para %s (formato y concordancia del modelo con el kit).\n', encargo);
    fprintf('La validación no certifica la corrección científica de los resultados.\n');
else
    fprintf('results.json NO válido para %s:\n', encargo);
    fprintf('  - %s\n', errores{:});
end
end

function errores = exigir(errores, s, campos, donde)
for i = 1:numel(campos)
    c = campos{i};
    if ~isfield(s, c)
        errores{end+1} = sprintf('%s: falta "%s"', donde, c);
    elseif isempty(s.(c))
        errores{end+1} = sprintf('%s: "%s" está vacío o es null', donde, c);
    end
end
end
