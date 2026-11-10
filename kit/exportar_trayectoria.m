function exportar_trayectoria(log, archivo)
%EXPORTAR_TRAYECTORIA Escribe trayectorias/Cx.csv con las columnas de la guía (sección 2.6).
n = numel(log.u);
M = [log.t(1:n), log.x(1:n,:), log.xh, log.uc, log.u];
fid = fopen(archivo, 'w');
fprintf(fid, 't,theta,alpha,dtheta,dalpha,theta_h,alpha_h,dtheta_h,dalpha_h,u_c,u\n');
fprintf(fid, [repmat('%.9g,', 1, 10) '%.9g\n'], M');
fclose(fid);
end
