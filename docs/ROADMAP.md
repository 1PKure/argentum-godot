# Prioridades de la arena PvP

La base integrada es `Alpha`. El objetivo es una arena web jugable con otra persona o con un bot; PvE queda fuera del alcance actual. Importar datos de AO20 no equivale a tener todos sus sistemas implementados. El catálogo tiene 213 entradas y 39 hechizos habilitados; todavía se usa un perfil de prueba, no el balance de una clase final.

| Orden | Sistema y alcance | Criterio para avanzar |
| --- | --- | --- |
| 1 · Actual | Feedback y controles: efectos sobre el personaje y siguiéndolo, palabras/daño/curación con anclas separadas, meditación más chica, pociones compatibles y ordenar las provisiones. | Dos clientes ven el mismo resultado; arrastrar no usa ni duplica objetos; nada queda pegado al suelo al moverse. |
| 2 · Seguimiento | Fluidez y red: medir movimiento sostenido, giros, colisiones, apuntado y respuesta al lanzar con latencia real. La velocidad actual se conserva por ahora; el ajuste fino no bloquea el avance a clases y lobbies. Corregir según mediciones antes de agregar predicción/reconciliación. | Registrar latencia y pasos aceptados/rechazados; probar dos equipos con demoras de 0/80/150 ms y jitter. Definir una tolerancia de respuesta con pruebas de juego. |
| 3 · Próximo sistema | Clases y contrato de combate PvP: perfiles de Mago, Clérigo, Bardo y Cazador no mágico; equipo y hechizos predeterminados, vida/maná, defensa y resistencias, permisos e intervalos. Ataque físico a distancia para el Cazador. | Cada preset funciona en servidor; equipo, costes y efectos se aplican una sola vez. El Cazador puede completar un duelo sin magia y el servidor rechaza hechizos ajenos a la clase. Valores iniciales documentados, con balance fino posterior. |
| 4 | Partida y lobby: crear/unirse, elegir clase/preset antes de empezar, estado esperando/listo, inicio, aparición, victoria/derrota, revancha, salida y desconexión. Aislar cada lobby en el servidor. | Dos lobbies simultáneos no comparten daño, jugadores ni eventos; una desconexión resuelve la partida sin dejarla trabada. |
| 5 | Bot del lobby: rival opcional cuando falta otro usuario, con movimiento, lanzamiento, pociones y dificultad básica. Usa las mismas reglas e intervalos del servidor. | Una persona puede completar y repetir un duelo; el bot no gasta ni obtiene recursos fuera de las reglas. Definir el reemplazo por otro humano entre partidas. |
| 6 | Sesión privada en servidor remoto WSS: despliegue del dedicado, acceso privado, logs y recuperación ante reinicio; dejar de depender del servidor de la PC para probar con otros equipos. | Se entra desde dos equipos sin usar localhost, no se amplía la audiencia sin autorización y se puede diagnosticar una desconexión. Prepararlo antes si hace falta para las pruebas de latencia del paso 2. |
| 7 | Diseño propio y balance: sustituir arte/distribución, perfiles finales, legibilidad, sonidos y ajustes con duelos repetibles. | El rediseño conserva controles y estados validados; se evalúan resultados de partidas, no sólo capturas. |

## Clases y presets dentro del punto 3

1. Definir un perfil inicial por clase: Mago, Clérigo, Bardo y Cazador no mágico. Cada preset reúne hechizos permitidos, equipo inicial y atributos efectivos, incluyendo vida/maná y modificadores de daño, defensa y resistencia que se implementen. Los valores iniciales son de prueba, no balance final.
2. Aplicar y validar esos perfiles en el servidor. El cliente solicita un ID de preset; no decide sus propios atributos, equipo ni permisos. El Cazador necesita arco/ataque a distancia e intervalos funcionales: esconder el libro de hechizos no alcanza para convertirlo en una clase jugable. Su política de pociones, recuperación y munición debe definirse explícitamente.
3. Conectar la elección al lobby del punto 4, con presentación del equipo/hechizos y confirmación antes de iniciar. Cambiar de clase se permite entre partidas, con un reinicio controlado por el servidor; no puede servir para curarse o cambiar equipo en medio del duelo. El bot del punto 5 usa esos mismos perfiles y restricciones.

No hace falta implementar creación de personajes persistentes, niveles ni inventario completo para estos presets de arena. Sí hace falta aplicar realmente las propiedades del equipo que se muestren en la interfaz. La elección exacta de hechizos y objetos se define al implementar los perfiles, reutilizando datos AO20 disponibles y documentando las adaptaciones.

## Límites y dependencias

- Ordenar las dos pociones de provisión es una preferencia visual local, guardada por dispositivo. Inventario real con cantidades, equipo, comercio y persistencia de personaje es otro sistema; debe ser autoritativo antes de que esos objetos tengan valor de juego.
- La disposición y legibilidad de la interfaz se corrigen durante todo el trabajo. El cambio completo de identidad gráfica puede esperar hasta estabilizar controles y estados.
- No agregar PvE, progresión, mundo persistente o más hechizos por cantidad antes de completar una partida PvP repetible.

## Flujo de cambios

Una rama por tarea creada desde el `Alpha` actualizado y un PR cuya base sea directamente `Alpha`. Probar la rama con servidor y clientes de la misma revisión. Integrarla cuando ese cambio esté validado; el siguiente cambio parte del nuevo `Alpha`. No hace falta acumular varios PR ni esperar a terminar toda la etapa Alpha. No usar otra rama de trabajo como base salvo que se acuerde una dependencia explícita.
