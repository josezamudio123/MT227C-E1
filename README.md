# MT227C — Laboratorio Calificado N.° 3 y N.° 4 — Encargo E1

**La ecuación de Riccati y el diseño de las ponderaciones** — Control óptimo de un péndulo de Furuta
(Quanser QUBE-Servo 2) accionado por tensión.
Universidad Nacional de Ingeniería — Facultad de Ingeniería Mecánica — Ingeniería Mecatrónica — 2026-2.
Docente: Dr. Alcides Guillermo Joo Aguayo.

| Integrante | Código | Subsección responsable |
|---|---|---|
| Zamudio Salazar, Joseluis Omar | 20193529C | E1.4–E1.6 (Pareto, optimización con restricciones y LMI, región de atracción), escenarios C1–C4 y repositorio |
| Nava Laburiano, David Adrián | 20211012C | E1.1–E1.3 (métodos de Riccati, verificación y estrés numérico); verificación cruzada de los códigos |

## Cómo reproducir todo

En MATLAB, desde esta carpeta:

```matlab
run_all
```

Regenera el modelo, las pruebas, los incisos E1.1–E1.6, la bonificación LMI, los escenarios C1–C4,
las trayectorias, los videos y `results.json` (validado con `validar_results` del kit).
Tiempo medido: **6.4 min** en un portátil (Windows 11, MATLAB R2026b). El registro completo de esa
corrida está en `resultados/run_all_log.txt`.

**Cachés** (permitidas por la guía, sección 2.6: cálculos largos con semilla fija). `run_all` las usa
por defecto; para recalcular todo, poner `regenerar = true` en `run_all.m` (unos 50 min):

| Archivo | Contenido | Tiempo sin caché |
|---|---|---|
| `resultados/E1_3_ref.mat` | referencias en precisión extendida (vpa, 40 dígitos) | ~5 min |
| `resultados/E1_4_sim.mat` | 1875 simulaciones no lineales de la malla de pesos | ~5 min |
| `resultados/E1_5_cache.mat` | optimización con `fminsearch` y validación (20 semillas) | ~10 min |
| `resultados/E1_5b_cache.mat` | malla con 5 semillas y validación (semillas 101–120) | ~11 min |

**Números del informe.** Ningún número del informe se escribe a mano: cada script los registra con
`src/anotar.m`, `generar_results.m` los copia a `results.json` (clave `valores_informe`) y escribe
`informe/valores_E1.tex`, que el informe lee con `\V{clave}`. `generar_results` avisa si el informe usa una
clave que no existe.

**Referencias.** `verificar_referencias` (requiere internet; no está en `run_all`) consulta Crossref para cada
DOI de `informe/referencias.bib` y escribe `informe/verificacion_referencias.tex` con tres estados: resuelve,
metadatos coinciden y respaldo revisado (este último lo marca el grupo con `revisado = {si}` tras leer la fuente).

**Informe.** En `informe/`: `latexmk -pdf informe_E1.tex`, `latexmk -pdf anexo_IA_E1.tex` y `latexmk -pdf resumen_en_E1.tex`
(resumen de resultados en inglés, una página más figuras).

## Software

- MATLAB R2026b Update 1 (26.2.0.3433840), Windows 11.
- Symbolic Math Toolbox (E1.3 referencia `vpa`; deducción simbólica en `modelo_propio.m`).
- Control System Toolbox (`icare`, `lqr`, `margin`; `icare` también está en `toolbox/shared/controllib`).
- Robust Control Toolbox (LMI Lab: bonificación de E1.5, `src/lqr_region_lmi.m`).
- Kit MT227C v1.1.1 del docente (carpeta `kit/`, sin modificar).
- LaTeX (`pdflatex` / `latexmk`) para `informe/`.

## Estructura

| Ruta | Contenido |
|---|---|
| `kit/` | Kit oficial del docente (simulador, escenarios, métricas, validador). No se modifica. |
| `src/` | Funciones propias: solucionadores de Riccati (Hamiltoniana, Schur, Newton–Kleinman, haz extendido, `vpa`), Lyapunov, escalado, LMI, simulador por lotes, diseño final. |
| `modelo_propio.m` | Modelo por Euler–Lagrange, linealización por el jacobiano y verificación contra el kit (OE1). |
| `pruebas_E1.m` | Pruebas con respuesta conocida del encargo. |
| `e1_1_metodos.m` … `e1_6_region.m` | Un script por inciso (E1.1–E1.6; E1.3 y E1.5 en varias partes). |
| `escenarios_E1.m` | Escenarios C1–C4 con el diseño final, trayectorias y videos. |
| `generar_results.m` | `results.json` desde los resultados guardados + tabla de escenarios del informe. |
| `crear_caches_E1_5.m` | Uso único: arma las cachés de E1.5 desde resultados ya calculados. |
| `resultados/` | Resultados `.mat`, cachés y registro de `run_all`. |
| `figuras/` | Figuras de todos los incisos. |
| `trayectorias/` | `C1.csv` … `C3b.csv` (columnas de la guía, sección 2.6). |
| `videos/` | `C1.mp4`, `C2.mp4` generados con `animar_qube`. |
| `informe/` | Fuentes LaTeX del informe técnico y del anexo de uso de IA (`informe_E1.tex`, `anexo_IA_E1.tex`). |
| `ia/` | Exportación de la conversación con el asistente de IA. |
| `predicciones.md` | Predicciones del hito H1 (registradas el 2026-11-07 por correo institucional). |

## Diseño final

`src/diseno_final.m`: diseño base $K_0$ (Q0, R0). Regla del grupo: se cambia solo si la mejora del costo
oficial promedio es estadísticamente significativa en semillas independientes; ningún candidato la
cumplió (E1.5).
