# Predicciones — Encargo E1 (hito H1)

MT227C Control Moderno y Óptimo — Laboratorio Calificado N.° 3 y N.° 4 — 2026-2
Formato: Anexo C de la guía v0.3. Registradas ANTES de cualquier simulación de los incisos E1.1–E1.6.

> El registro oficial es el enviado por aula virtual / correo institucional (sello de tiempo).
> Este archivo y su commit lo complementan, no lo sustituyen.

| Campo | P1 | P2 | P3 |
|---|---|---|---|
| **id** | E1-P1 | E1-P2 | E1-P3 |
| **registro** | 2026-11-07, ~16:42 (hora de Lima), correo institucional | ídem | ídem |
| **inciso** | E1.6 — Región de atracción | E1.5 — Optimización con restricciones (C2) | E1.3 — Estrés numérico |
| **enunciado** | El certificado elipsoidal {x'P0x ≤ ρ} del diseño base no garantiza ángulos iniciales del péndulo mayores que 0.055 rad (con los demás estados en cero), mientras que la estimación por Monte Carlo sobre la planta no lineal recuperará el péndulo desde ángulos al menos 5 veces mayores (≥ 0.27 rad). | Para cumplir C2 (\|θ\| ≤ π/2 en todo el ensayo y fracción de tiempo saturado ≤ 5 %) será necesario aumentar el peso del esfuerzo al menos 10 veces respecto del diseño base (R ≥ 10·R0 = 0.1), o equivalentemente reducir la ganancia del péndulo a \|K2\| ≤ 40 V/rad (K0 tiene 182.5 V/rad). | Al reducir R desde 1 hasta 1e-8, el error directo (frente a la referencia en precisión extendida) del método de vectores propios de la Hamiltoniana crecerá más rápido que el del método de Schur ordenado; con R = 1e-8, Hamiltoniana con error > 1e-6 y Schur con error < 1e-9. |
| **tipo** | LIMITE | ORDEN | SIGNO |
| **base** | TEORIA | TEORIA | TEORIA + IA |
| **justificación** | Sobre el eje α: u = −K2·α con K2 = 182.5 V/rad; \|u\| ≤ 10 V exige α ≤ 10/182.5 = 0.055 rad, y el elipsoide certificado debe caber en esa franja. El kit muestra que el diseño base ya se recupera en C2 (α0 = 0.35 rad) saturando. | En C2, \|u_c(0)\| ≈ K2·α0 = 182.5 × 0.35 ≈ 64 V (el kit da 63.87 V). Para operar cerca de 10 V, K2 debe bajar ~5–6 veces; como K escala aproximadamente con R^(−1/2), R debe crecer ~25–36 veces. | Laub (1979): los vectores propios de H se vuelven mal condicionados cuando sus autovalores se separan mucho; con R pequeño crecen los polos rápidos del lazo cerrado. Nota: en el diseño base (pruebas_E1) Schur dio 2.4e-12 y la Hamiltoniana 2.4e-15, por lo que la predicción puede no cumplirse. |
| **resultado** | Certificado 0.0377 rad; recuperación desde 0.430 rad (estado real) y 0.378 rad con éxito en el simulador oficial | El diseño base (R0, K2 = 182.5 V/rad) ya cumple C2: saturado 1.9 %, max|θ| = 1.345 rad. Con Q0 y R ≥ 17.8·R0 (K2 ≤ 60) el brazo supera π/2 | R = 1e-8: Hamiltoniana 3.6e-9, Schur 1.2e-4; pendientes log-log −0.85 y −1.17 |
| **acierto** | SI: el certificado queda bajo Vmax/|K2| = 0.055 rad y la región real es 10 a 11 veces mayor (e1_6_region.m) | NO: tendencia opuesta; la saturación dura ~95 ms y un regulador más suave deja que el brazo se aleje más (e1_5_restricciones.m, etapa C) | NO: tendencia opuesta. eig() balancea H por defecto y schur() no; con el mismo balanceo ambos dan el mismo error (e1_3b_balanceo.m) |
