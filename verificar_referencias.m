%VERIFICAR_REFERENCIAS  Comprueba las referencias de informe/referencias.bib contra Crossref
%   (guía, sección 4.4) y escribe informe/verificacion_referencias.tex (anexo del informe).
%   Tres estados por referencia con DOI:
%     resuelve             el DOI existe en Crossref (un fallo de red se registra como "no verificado",
%                          no como cita falsa);
%     metadatos coinciden  título, año y apellido del primer autor coinciden con los del .bib;
%     respaldo revisado    un integrante leyó la fuente y confirmó que respalda lo que se le atribuye
%                          (campo revisado = {si} en el .bib; lo decide el grupo, no este script).
%   Las referencias sin DOI (manuales) se citan con registro estable: editor, versión y año.
%   Requiere conexión a internet. No forma parte de run_all para no depender de la red.

clear; clc;
raiz = fileparts(mfilename('fullpath'));
txt = fileread(fullfile(raiz, 'informe', 'referencias.bib'));
ent = regexp(txt, '@(\w+)\{(\w+),(.*?)\n\s*revisado\s*=\s*\{(\w+)\}\}', 'tokens');
op = weboptions('Timeout', 20, 'ContentType', 'json');
fila = {}; n = [0 0 0 0];                          % [con DOI, resuelve, coinciden, revisado]
fprintf('%-15s %-34s %-13s %-11s %-9s\n', 'clave', 'DOI', 'resuelve', 'metadatos', 'revisado');
for i = 1:numel(ent)
    clave = ent{i}{2}; cuerpo = ent{i}{3}; revisado = strcmpi(ent{i}{4}, 'si');
    doi    = campo(cuerpo, 'doi');
    titulo = regexp(cuerpo, 'title\s*=\s*\{(.*?)\},\s*\n?\s*(journal|publisher|edition|organization)', 'tokens', 'once');
    titulo = limpiar(titulo{1});
    anio   = str2double(campo(cuerpo, 'year'));
    autor  = strtrim(strtok(limpiar(campo(cuerpo, 'author')), ','));
    if isempty(doi)
        fila(end+1, :) = {clave, '--', 'sin DOI', '--', ternario(revisado, 'sí', 'pendiente')}; %#ok<SAGROW>
        fprintf('%-15s %-34s %-13s\n', clave, '(sin DOI)', 'registro estable');
        continue
    end
    n(1) = n(1) + 1;
    try
        r = webread(['https://api.crossref.org/works/' doi], op); m = r.message;
        res = 'sí'; n(2) = n(2) + 1;
        tc = m.title; if iscell(tc), tc = strjoin(tc, ' '); end
        if isfield(m, 'subtitle') && ~isempty(m.subtitle), st = m.subtitle; if iscell(st), st = strjoin(st, ' '); end, tc = [tc ' ' st]; end
        pal = regexp(normalizar(titulo), '\s+', 'split'); pal = pal(strlength(pal) > 3);
        ok_t = mean(cellfun(@(w) contains(normalizar(tc), w), pal)) >= 0.8;
        dp = m.issued.date_parts; ok_a = dp(1) == anio;
        fam = ''; if isfield(m, 'author'), a1 = m.author(1); if iscell(a1), a1 = a1{1}; end, if isfield(a1, 'family'), fam = a1.family; end, end
        ok_p = ~isempty(fam) && contains(normalizar(autor), normalizar(fam));
        campos = {'título', 'año', 'autor'};
        met = ternario(ok_t && ok_a && ok_p, 'sí', sprintf('no (%s)', strjoin(campos([~ok_t ~ok_a ~ok_p]), ', ')));
        n(3) = n(3) + (ok_t && ok_a && ok_p);
    catch err
        res = 'no verificado'; met = '--';
        fprintf(2, '  %s: %s\n', clave, err.message);
    end
    n(4) = n(4) + revisado;
    fila(end+1, :) = {clave, doi, res, met, ternario(revisado, 'sí', 'pendiente')}; %#ok<SAGROW>
    fprintf('%-15s %-34s %-13s %-11s %-9s\n', clave, doi, res, met, fila{end, 5});
end
fprintf('\nCon DOI: %d | resuelven: %d | metadatos coinciden: %d | respaldo revisado: %d\n', n);

f = fopen(fullfile(raiz, 'informe', 'verificacion_referencias.tex'), 'w');
fprintf(f, '%% Generado por verificar_referencias.m (%s). No editar a mano.\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
fprintf(f, 'Consulta a Crossref del %s. Con DOI: %d; resuelven: %d; metadatos coinciden: %d; respaldo revisado por el grupo: %d.\n\n', ...
        char(datetime('now', 'Format', 'yyyy-MM-dd')), n);
fprintf(f, '{\\footnotesize\\begin{longtable}{@{}l l l l l@{}}\n\\toprule\nClave & DOI & Resuelve & Metadatos & Respaldo revisado \\\\\n\\midrule\\endhead\n');
for i = 1:size(fila, 1)
    fprintf(f, '%s & \\texttt{%s} & %s & %s & %s \\\\\n', fila{i, 1}, strrep(fila{i, 2}, '_', '\_'), fila{i, 3:5});
end
fprintf(f, '\\bottomrule\n\\end{longtable}}\n');
fclose(f);
fprintf('Escrito: informe/verificacion_referencias.tex\n');

function v = campo(c, nombre)
t = regexp(c, ['\<' nombre '\s*=\s*\{([^}]*)\}'], 'tokens', 'once');
if isempty(t), v = ''; else, v = strtrim(t{1}); end
end
function s = limpiar(s)
s = regexprep(s, '[{}$\\]', ''); s = regexprep(s, '\s+', ' ');
end
function s = normalizar(s)
s = lower(char(s));
s = regexprep(s, {'[áà]', '[éè]', '[íì]', '[óò]', '[úùü]', 'ñ'}, {'a', 'e', 'i', 'o', 'u', 'n'});
s = regexprep(s, '[^a-z0-9 ]', ' '); s = strtrim(regexprep(s, '\s+', ' '));
end
function s = ternario(c, a, b)
if c, s = a; else, s = b; end
end
