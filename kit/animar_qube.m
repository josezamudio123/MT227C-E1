function animar_qube(log, opts)
%ANIMAR_QUBE Animación 3D del brazo y del péndulo desde un registro de simular_qube.
%   animar_qube(log)
%   animar_qube(log, opts) con los campos opcionales:
%     .archivo       ''     si se indica (p. ej. 'C1_E1.mp4'), guarda un video con
%                           VideoWriter (MATLAB). Si VideoWriter no existe (GNU Octave),
%                           se emite un aviso y no se guarda video.
%     .fps           30     cuadros por segundo del video y de la reproducción en pantalla
%     .velocidad     1      factor de tiempo: 1 = tiempo real, 0.5 = cámara lenta
%     .tiempo_real   true   en pantalla, espera para respetar 'velocidad' (si el equipo
%                           es lento, la reproducción puede ir más lenta, nunca más rápida)
%     .visible       true   mostrar la figura
%   El video siempre tiene la velocidad nominal 'velocidad' (fps cuadros por segundo,
%   cada cuadro avanza velocidad/fps segundos de simulación), con independencia de lo
%   que tarde el equipo en dibujar. Se incluyen siempre el primer y el último instante.
%   Los ángulos dibujados son exactamente log.x(:,1) y log.x(:,2) en los instantes log.t.
if nargin < 2, opts = struct(); end
op = struct('archivo', '', 'fps', 30, 'velocidad', 1, 'tiempo_real', true, 'visible', true);
fn = fieldnames(opts); for j = 1:numel(fn), op.(fn{j}) = opts.(fn{j}); end
p = log.esc.p; t = log.t; X = log.x;
idx = cuadros_qube(t, op.velocidad/op.fps);
if op.visible, vis = 'on'; else, vis = 'off'; end
fig = figure('Color', 'w', 'Visible', vis, 'Name', ['QUBE - ' log.esc.nombre]);
ax = axes('Parent', fig);
[hB, hP, hM] = escena_qube(ax, p, [0.35 0.35 0.35], [0.85 0.1 0.1]);
hTit = title(ax, '');
grabar = false;
if ~isempty(op.archivo)
    if exist('VideoWriter', 'file') == 2 || exist('VideoWriter', 'class') == 8
        [~, ~, ext] = fileparts(op.archivo);
        if strcmpi(ext, '.mp4'), vw = VideoWriter(op.archivo, 'MPEG-4');
        else, vw = VideoWriter(op.archivo); end
        vw.FrameRate = op.fps; open(vw); grabar = true;
    else
        warning('animar_qube: VideoWriter no está disponible en este entorno; no se guarda video.');
    end
end
reloj = tic;
for n = 1:numel(idx)
    k = idx(n);
    dibujar_qube(hB, hP, hM, X(k,1), X(k,2), p);
    set(hTit, 'String', sprintf('%s   t = %.3f s   \\theta = %+.3f rad   \\alpha = %+.3f rad', ...
        log.esc.nombre, t(k), X(k,1), X(k,2)));
    drawnow;
    if grabar, writeVideo(vw, getframe(fig)); end
    if op.tiempo_real && op.visible
        espera = (t(k) - t(idx(1)))/op.velocidad - toc(reloj);
        if espera > 0, pause(espera); end
    end
end
if grabar, close(vw); fprintf('Video guardado: %s\n', op.archivo); end
end
