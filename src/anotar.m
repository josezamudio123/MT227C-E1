function anotar(clave, valor, formato)
%ANOTAR  Registra un número que el informe cita, para que el informe lo tome de results.json.
%   anotar(clave, valor, formato) guarda {valor, formato} en resultados/valores_informe.mat.
%   generar_results.m copia los valores a results.json (clave "valores_informe") y escribe
%   informe/valores_E1.tex, de donde el informe los lee con \V{clave}. Así ningún número del
%   informe se copia a mano (guía, sección 7: todo número del informe coincide con results.json).
%   formato: 'e0'..'e3' notación científica con 0 a 3 decimales; 'f0'..'f6' decimales fijos;
%            'p0'..'p2' porcentaje (100*valor); 'g3' tres cifras significativas; 'd' entero.
archivo = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'resultados', 'valores_informe.mat');
assert(isvarname(clave), 'anotar: clave no válida: %s', clave);
assert((isnumeric(valor) || islogical(valor)) && isscalar(valor), 'anotar: %s debe ser un escalar', clave);
V = struct();
if isfile(archivo), S = load(archivo, 'V'); V = S.V; end
V.(clave) = struct('valor', double(valor), 'formato', formato);
save(archivo, 'V');
end
