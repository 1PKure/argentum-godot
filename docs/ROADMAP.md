# Prioridades de la arena PvP

La base integrada es `Alpha`. El objetivo es una arena web jugable con otra persona o con un bot; PvE queda fuera del alcance actual. Importar datos de AO20 no equivale a tener todos sus sistemas implementados. El catálogo tiene 213 entradas y 39 hechizos habilitados; todavía se usa un perfil de prueba, no el balance de una clase final.

| Orden | Sistema y alcance | Criterio para avanzar |
| --- | --- | --- |
| 1 · Actual | Feedback y controles: efectos sobre el personaje y siguiéndolo, palabras/daño/curación con anclas separadas, meditación más chica, pociones compatibles y ordenar las provisiones. | Dos clientes ven el mismo resultado; arrastrar no usa ni duplica objetos; nada queda pegado al suelo al moverse. |
| 2 | Fluidez y red: medir movimiento sostenido, giros, colisiones, apuntado y respuesta al lanzar con latencia real. Corregir según mediciones antes de agregar predicción/reconciliación. | Registrar latencia y pasos aceptados/rechazados; probar dos equipos con demoras de 0/80/150 ms y jitter. Definir una tolerancia de respuesta con pruebas de juego. |
| 3 | Contrato de combate PvP: fijar una selección inicial de hechizos, tipos de objetivo, alcance/obstáculos, parálisis/remo, intervalos, muerte y recuperación. Completar atributos, equipo, skills y fórmulas sólo cuando esa selección los requiera. | Cada hechizo seleccionado tiene reglas documentadas y casos de éxito/rechazo en servidor; coste y efecto se aplican una sola vez y el feedback coincide. No es requisito habilitar las 213 entradas. |
| 4 | Partida y lobby: crear/unirse, estado esperando/listo, inicio, aparición, victoria/derrota, revancha, salida y desconexión. Aislar cada lobby en el servidor. | Dos lobbies simultáneos no comparten daño, jugadores ni eventos; una desconexión resuelve la partida sin dejarla trabada. |
| 5 | Bot del lobby: rival opcional cuando falta otro usuario, con movimiento, lanzamiento, pociones y dificultad básica. Usa las mismas reglas e intervalos del servidor. | Una persona puede completar y repetir un duelo; el bot no gasta ni obtiene recursos fuera de las reglas. Definir el reemplazo por otro humano entre partidas. |
| 6 | Sesión privada en servidor remoto WSS: despliegue del dedicado, acceso privado, logs y recuperación ante reinicio; dejar de depender del servidor de la PC para probar con otros equipos. | Se entra desde dos equipos sin usar localhost, no se amplía la audiencia sin autorización y se puede diagnosticar una desconexión. Prepararlo antes si hace falta para las pruebas de latencia del paso 2. |
| 7 | Diseño propio y balance: sustituir arte/distribución, perfiles finales, legibilidad, sonidos y ajustes con duelos repetibles. | El rediseño conserva controles y estados validados; se evalúan resultados de partidas, no sólo capturas. |

## Límites y dependencias

- Ordenar las dos pociones de provisión es una preferencia visual local, guardada por dispositivo. Inventario real con cantidades, equipo, comercio y persistencia de personaje es otro sistema; debe ser autoritativo antes de que esos objetos tengan valor de juego.
- La disposición y legibilidad de la interfaz se corrigen durante todo el trabajo. El cambio completo de identidad gráfica puede esperar hasta estabilizar controles y estados.
- No agregar PvE, progresión, mundo persistente o más hechizos por cantidad antes de completar una partida PvP repetible.

## Flujo de cambios

Una rama por tarea creada desde el `Alpha` actualizado y un PR cuya base sea directamente `Alpha`. Probar la rama con servidor y clientes de la misma revisión. Integrarla cuando ese cambio esté validado; el siguiente cambio parte del nuevo `Alpha`. No hace falta acumular varios PR ni esperar a terminar toda la etapa Alpha. No usar otra rama de trabajo como base salvo que se acuerde una dependencia explícita.
