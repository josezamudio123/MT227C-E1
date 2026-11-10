function fig = animar_qube_interactivo(logs, nombres)
%ANIMAR_QUBE_INTERACTIVO Visor interactivo de una o dos simulaciones del QUBE.
%   animar_qube_interactivo(log)
%   animar_qube_interactivo({log1, log2}, {'Diseño base', 'Diseño del grupo'})
%
%   Controles:
%     Reproducir / Pausa   inicia o detiene la reproducción (también con la barra espaciadora)
%     Deslizador           salta a cualquier instante (también con las flechas izquierda/derecha)
%     Velocidad            0.1x, 0.25x, 0.5x, 1x (tiempo real), 2x, 4x
%     Vista                3D, superior, frontal, lateral; con el ratón se puede rotar la vista 3D
%     Inicio               vuelve a t = 0
%     Guardar video        exporta la primera simulación con animar_qube (requiere VideoWriter)
%   A la derecha se muestran theta(t), alpha(t) y u(t) con un cursor en el instante actual.
%   Con dos simulaciones, la segunda se dibuja en azul sobre la misma escena y en las gráficas.
%   Los valores mostrados son exactamente los de log.t y log.x (sin interpolación).

if isstruct(logs), logs = {logs}; end
if nargin < 2
    nombres = cell(1, numel(logs));
    for j = 1:numel(logs), nombres{j} = logs{j}.esc.nombre; end
end
if numel(logs) > 2, error('animar_qube_interactivo: se admiten una o dos simulaciones.'); end
p = logs{1}.esc.p;
colPend = {[0.85 0.10 0.10], [0.10 0.30 0.85]};
colBrazo = {[0.35 0.35 0.35], [0.45 0.55 0.75]};

fig = figure('Color', 'w', 'Name', 'QUBE-Servo 2 - visor interactivo', 'NumberTitle', 'off', ...
             'Units', 'normalized', 'Position', [0.08 0.12 0.82 0.72]);
% Escena 3D
ax3 = axes('Parent', fig, 'Position', [0.04 0.20 0.50 0.72]);
S.hB = cell(1, numel(logs)); S.hP = S.hB; S.hM = S.hB;
[S.hB{1}, S.hP{1}, S.hM{1}] = escena_qube(ax3, p, colBrazo{1}, colPend{1});
for j = 2:numel(logs)
    [S.hB{j}, S.hP{j}, S.hM{j}] = escena_qube(ax3, logs{j}.esc.p, colBrazo{j}, colPend{j});
end
S.hTit = title(ax3, '');
% Gráficas temporales
etiquetas = {'\theta [rad]', '\alpha [rad]', 'u [V]'};
S.axT = zeros(1, 3); S.cursor = zeros(1, 3);
for i = 1:3
    S.axT(i) = axes('Parent', fig, 'Position', [0.62 0.72 - (i-1)*0.26 0.35 0.20]);
    hold(S.axT(i), 'on'); grid(S.axT(i), 'on'); ylabel(S.axT(i), etiquetas{i});
    for j = 1:numel(logs)
        L = logs{j};
        switch i
            case 1, plot(S.axT(i), L.t, L.x(:,1), 'Color', colPend{j}, 'LineWidth', 1.2);
            case 2, plot(S.axT(i), L.t, L.x(:,2), 'Color', colPend{j}, 'LineWidth', 1.2);
            case 3
                plot(S.axT(i), L.t(1:end-1), L.uc, '--', 'Color', 0.6*colPend{j} + 0.4, 'LineWidth', 0.8);
                stairs(S.axT(i), L.t(1:end-1), L.u, 'Color', colPend{j}, 'LineWidth', 1.2);
        end
    end
    yl = get(S.axT(i), 'YLim');
    S.cursor(i) = plot(S.axT(i), [0 0], yl, 'k-', 'LineWidth', 1);
end
xlabel(S.axT(3), 't [s]');
if numel(logs) == 2
    legend(S.axT(1), nombres, 'Location', 'best');
end
plot(S.axT(3), [logs{1}.t(1) logs{1}.t(end)], p.Vmax*[1 1], ':', 'Color', [0.4 0.4 0.4]);
plot(S.axT(3), [logs{1}.t(1) logs{1}.t(end)], -p.Vmax*[1 1], ':', 'Color', [0.4 0.4 0.4]);

% Controles
S.logs = logs; S.nombres = nombres; S.p = p;
S.t = logs{1}.t; S.k = 1; S.jugando = false;
S.velocidades = [0.1 0.25 0.5 1 2 4];
S.btnPlay = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Reproducir', 'Units', 'normalized', ...
    'Position', [0.04 0.06 0.09 0.06], 'FontSize', 11, 'Callback', @(h, e) cb_play(fig));
uicontrol(fig, 'Style', 'pushbutton', 'String', 'Inicio', 'Units', 'normalized', ...
    'Position', [0.14 0.06 0.06 0.06], 'Callback', @(h, e) cb_inicio(fig));
S.slider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', 'Position', [0.21 0.075 0.33 0.035], ...
    'Min', 1, 'Max', numel(S.t), 'Value', 1, ...
    'SliderStep', [1/(numel(S.t)-1), 50/(numel(S.t)-1)], 'Callback', @(h, e) cb_slider(fig));
S.txt = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.21 0.03 0.33 0.035], ...
    'BackgroundColor', 'w', 'String', '');
uicontrol(fig, 'Style', 'text', 'String', 'Velocidad', 'Units', 'normalized', ...
    'Position', [0.56 0.10 0.07 0.03], 'BackgroundColor', 'w');
S.popVel = uicontrol(fig, 'Style', 'popupmenu', 'String', {'0.1x','0.25x','0.5x','1x (tiempo real)','2x','4x'}, ...
    'Value', 4, 'Units', 'normalized', 'Position', [0.56 0.05 0.09 0.05]);
uicontrol(fig, 'Style', 'text', 'String', 'Vista', 'Units', 'normalized', ...
    'Position', [0.66 0.10 0.07 0.03], 'BackgroundColor', 'w');
S.popVista = uicontrol(fig, 'Style', 'popupmenu', 'String', {'3D','Superior','Frontal','Lateral'}, ...
    'Value', 1, 'Units', 'normalized', 'Position', [0.66 0.05 0.08 0.05], 'Callback', @(h, e) cb_vista(fig));
S.btnVideo = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Guardar video', 'Units', 'normalized', ...
    'Position', [0.76 0.05 0.10 0.06], 'Callback', @(h, e) cb_video(fig));
if ~(exist('VideoWriter', 'file') == 2 || exist('VideoWriter', 'class') == 8)
    set(S.btnVideo, 'Enable', 'off', 'TooltipString', 'VideoWriter no disponible en este entorno');
end
S.ax3 = ax3;
set(fig, 'WindowKeyPressFcn', @(h, e) cb_tecla(fig, e), 'CloseRequestFcn', @(h, e) cb_cerrar(fig));
setappdata(fig, 'S', S);
actualizar(fig, 1);
end

% ---------------------------------------------------------------------
function actualizar(fig, k)
S = getappdata(fig, 'S');
k = max(1, min(numel(S.t), round(k)));
tk = S.t(k);
for j = 1:numel(S.logs)
    L = S.logs{j};
    [~, kj] = min(abs(L.t - tk));
    dibujar_qube(S.hB{j}, S.hP{j}, S.hM{j}, L.x(kj,1), L.x(kj,2), L.esc.p);
end
X = S.logs{1}.x;
set(S.hTit, 'String', sprintf('%s   t = %.3f s   \\theta = %+.3f rad   \\alpha = %+.3f rad', ...
    S.nombres{1}, tk, X(k,1), X(k,2)));
for i = 1:3, set(S.cursor(i), 'XData', [tk tk]); end
set(S.slider, 'Value', k);
set(S.txt, 'String', sprintf('t = %.3f s  de  %.3f s', tk, S.t(end)));
S.k = k; setappdata(fig, 'S', S);
drawnow;
end

function cb_slider(fig)
S = getappdata(fig, 'S');
actualizar(fig, get(S.slider, 'Value'));
end

function cb_inicio(fig)
S = getappdata(fig, 'S'); S.jugando = false; setappdata(fig, 'S', S);
set(S.btnPlay, 'String', 'Reproducir');
actualizar(fig, 1);
end

function cb_play(fig)
S = getappdata(fig, 'S');
if S.jugando
    S.jugando = false; setappdata(fig, 'S', S);
    set(S.btnPlay, 'String', 'Reproducir');
    return;
end
if S.k >= numel(S.t), S.k = 1; end
S.jugando = true; setappdata(fig, 'S', S);
set(S.btnPlay, 'String', 'Pausa');
t0 = S.t(S.k); reloj = tic;
while ishandle(fig)
    S = getappdata(fig, 'S');
    if ~S.jugando, break; end
    v = S.velocidades(get(S.popVel, 'Value'));
    tobj = t0 + v*toc(reloj);
    if tobj >= S.t(end)
        actualizar(fig, numel(S.t)); break;
    end
    [~, k] = min(abs(S.t - tobj));
    if k ~= S.k, actualizar(fig, k); else, pause(0.005); end
    % si el usuario cambia la velocidad, se reinicia la referencia de tiempo
    if v ~= S.velocidades(get(S.popVel, 'Value')), t0 = S.t(k); reloj = tic; end
end
if ishandle(fig)
    S = getappdata(fig, 'S'); S.jugando = false; setappdata(fig, 'S', S);
    set(S.btnPlay, 'String', 'Reproducir');
end
end

function cb_vista(fig)
S = getappdata(fig, 'S');
switch get(S.popVista, 'Value')
    case 1, view(S.ax3, 35, 22);
    case 2, view(S.ax3, 0, 90);
    case 3, view(S.ax3, 0, 0);
    case 4, view(S.ax3, 90, 0);
end
end

function cb_video(fig)
S = getappdata(fig, 'S');
nombre = [S.logs{1}.esc.nombre '.mp4'];
if exist('uiputfile', 'file')
    [f, ruta] = uiputfile('*.mp4', 'Guardar video', nombre);
    if isequal(f, 0), return; end
    nombre = fullfile(ruta, f);
end
v = S.velocidades(get(S.popVel, 'Value'));
animar_qube(S.logs{1}, struct('archivo', nombre, 'velocidad', v, 'tiempo_real', false));
end

function cb_tecla(fig, e)
S = getappdata(fig, 'S');
switch e.Key
    case 'space', cb_play(fig);
    case 'rightarrow', actualizar(fig, S.k + 10);
    case 'leftarrow', actualizar(fig, S.k - 10);
end
end

function cb_cerrar(fig)
S = getappdata(fig, 'S'); S.jugando = false; setappdata(fig, 'S', S);
delete(fig);
end
