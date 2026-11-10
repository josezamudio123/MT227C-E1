# Kit MT227C — Laboratorio Calificado N.° 3 y N.° 4 (v1.1.1)

Kit común de simulación del péndulo de Furuta QUBE-Servo 2 accionado por tensión. Todos los grupos
obtienen los resultados oficiales de los escenarios C1 a C5 con este simulador.

- Escrito para MATLAB R2021a o posterior, sin toolboxes. Si `lqr` está disponible, `diseno_base_qube` lo usa
  para comprobar K0.
- Probado en GNU Octave 8.4 (22 de 22 pruebas). La versión 1.1 se ejecutó en MATLAB (21 de 21 pruebas, videos C1 y C2
  generados); la 1.1.1 solo cambia el validador para C5. Ejecute `pruebas_kit` en su instalación antes de usarlo.
- La exportación de video requiere `VideoWriter` (MATLAB). En GNU Octave las animaciones se muestran en pantalla,
  pero no se guardan como video.

## Primer paso

```matlab
pruebas_kit       % debe terminar con "22 de 22 pruebas superadas"
ejemplo_run_all   % escenarios C1-C4 con el diseño base, CSV, JSON, videos y visor interactivo
```

## Archivos

| Archivo | Función |
|---|---|
| `parametros_qube.m` | Parámetros de la planta y del benchmark (sección 2.2 de la guía) |
| `masa_qube.m`, `modelo_qube.m` | Matriz de masa M(alpha) y dinámica no lineal de 4 estados con entrada de tensión |
| `lineal_qube.m` | Modelo linealizado de 4 estados, modelo de 5 estados con armadura y canal de perturbación |
| `diseno_base_qube.m`, `diseno_base_ref.json` | Diseño base K0, P0 y filtro de Kalman base (Ad, Bd, Qd, Rd, L0, Sigma0) |
| `controlador_lineal.m`, `estimador_base.m` | Controlador lineal y filtro base con la interfaz del simulador |
| `escenario_qube.m` | Escenarios C1, C2, C3, C3b, C4 (planta i) y C5 |
| `simular_qube.m` | Simulador oficial: planta no lineal, retención de orden cero, saturación, cuantización, ruido, impulso, retardo opcional |
| `metricas_qube.m` | Métricas del Anexo B de la guía |
| `resumen_c4.m` | Monte Carlo de C4 con semillas, factores, denominador y fallidos |
| `animar_qube.m` | Animación 3D y exportación a video |
| `animar_qube_interactivo.m` | Visor interactivo: reproducir/pausa, deslizador, velocidad, vistas, gráficas sincronizadas, comparación de dos diseños |
| `geometria_qube.m`, `escena_qube.m`, `dibujar_qube.m`, `cuadros_qube.m` | Funciones auxiliares de las animaciones |
| `exportar_trayectoria.m` | Escribe `trayectorias/Cx.csv` |
| `validar_results.m` | Validación automática de formato de `results.json` |
| `pruebas_kit.m`, `ejemplo_run_all.m` | Pruebas y ejemplo de uso |

## Interfaces

```matlab
% Controlador: cualquier ley, con memoria opcional (integrador, MPC, levantamiento, etc.)
ctrl.ley = @(xhat, t, mem) ...    % devuelve [u_c, mem]
ctrl.mem = [];

% Estimador
est.inicio     = @(y0) ...                   % devuelve [xhat, mem]
est.actualizar = @(xhat, y, u_ant, mem) ...  % devuelve [xhat, mem]

% Simulación
L = simular_qube(ctrl, est, escenario_qube('C2'), struct('semilla', 1));
```

Opciones de `simular_qube`: `ideal` (estado real, sin ruido ni cuantización; `false`), `semilla` (`1`),
`retardo` (0 o 1 muestra; `0`), `nsub` (subpasos RK4 por periodo; `4`), `ruido` (`true`).

Registro `L`: `t` y `x` en t_0..t_N (incluida la última muestra); `xh`, `uc`, `u` en t_0..t_{N-1}
(u constante en [t_k, t_{k+1})); `impulso` con el instante y el salto aplicado (C3, C3b).

## Animaciones

```matlab
L = simular_qube(ctrl, est, escenario_qube('C1'));
animar_qube_interactivo(L)                                  % visor interactivo
animar_qube_interactivo({L_base, L_grupo}, {'Base','Grupo'}) % comparación de dos diseños
animar_qube(L, struct('archivo', 'C1.mp4'))                 % video para la entrega (MATLAB)
```

Controles del visor: botón **Reproducir/Pausa** (o barra espaciadora), deslizador de tiempo (o flechas izquierda y
derecha), **Velocidad** de 0.1x a 4x (1x es tiempo real), **Vista** 3D, superior, frontal o lateral (la vista 3D
también se rota con el ratón), **Inicio** y **Guardar video**.

`animar_qube`: `velocidad` fija la escala de tiempo del video y de la reproducción en pantalla (1 = tiempo real);
`fps` fija los cuadros por segundo. El video siempre tiene la velocidad nominal; en pantalla, si el equipo es lento,
la reproducción puede ir más despacio, nunca más rápido. Se incluyen siempre el primer y el último instante.

**Cómo comprobar que la animación corresponde a los datos.** El título muestra t, theta y alpha tomados directamente
de `L.t` y `L.x` (sin interpolación), y en el visor el cursor de las gráficas marca el mismo instante. Detenga la
animación en un instante y compare con la fila correspondiente de `trayectorias/Cx.csv`. Las posiciones dibujadas
se calculan con `geometria_qube`, que `pruebas_kit` verifica: alpha = 0 coloca el extremo del péndulo en z = +Lp y
alpha = pi en z = -Lp.

## Convenciones

- `x = [theta; alpha; dtheta; dalpha]`, con `alpha = 0` arriba y `alpha = pi` abajo.
- Una tensión positiva desde el equilibrio superior produce `ddtheta > 0` y `ddalpha > 0`; en la animación, alpha > 0
  inclina el péndulo hacia atrás respecto del avance del brazo.
- Impulso de C3 y C3b: salto de velocidades `M(alpha)^-1 [I; 0]` en t = 1 s; el registro guarda el estado posterior
  al salto en esa muestra, y el estimador lo recibe a través de las mediciones siguientes.
- C4: planta i con semilla 1000 + i y factores uniformes en [0.8, 1.2] para `mp`, `Lp`, `Rm`, `kt` (`km = kt`);
  ruido con semilla i. Denominador: n plantas. Estadísticas solo sobre ensayos exitosos; los fallidos se listan.
- C5: alpha envuelto en (-pi, pi]; el costo de regulación empieza en el primer instante con |alpha| < 0.3 rad.

## Qué valida `validar_results` y qué no

Valida claves obligatorias, valores no vacíos ni null, dimensiones, concordancia de A, B y K0 con el kit,
estructura y estado de cada escenario, C5 solo para E4 (con `t_levantamiento` obligatorio si C5 es `"ok"` y admitido como `null` si es `"fallo"`) y métricas de E2 por filtro y condición. **No certifica la
corrección científica** de los resultados del encargo; eso se evalúa en la revisión técnica y en la defensa.

## Valores de referencia (diseño base, estado real, sin ruido ni cuantización)

| Escenario | max abs(u_c) [V] | max abs(theta) [rad] |
|---|---|---|
| C1 | 9.12 | 0.107 |
| C2 | 63.87 | 1.237 |
| C3 | 7.34 | 0.020 |
| C3b | 25.03 | 0.146 |

C5 no tiene valor de referencia: el kit no incluye un controlador de levantamiento.
