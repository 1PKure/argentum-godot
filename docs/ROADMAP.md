# Prioridades de la arena PvP

La base integrada es `Alpha`. El objetivo es una arena web jugable con otra persona o con un bot; PvE queda fuera del alcance actual. Importar datos de AO20 no equivale a tener todos sus sistemas implementados. El catálogo tiene 213 entradas y 39 hechizos habilitados; todavía se usa un perfil de prueba, no el balance de una clase final.

| Orden | Sistema y alcance | Criterio para avanzar |
| --- | --- | --- |
| 1 · Actual | Feedback y controles: efectos sobre el personaje y siguiéndolo, palabras/daño/curación con anclas separadas, meditación más chica, pociones compatibles y ordenar las provisiones. | Dos clientes ven el mismo resultado; arrastrar no usa ni duplica objetos; nada queda pegado al suelo al moverse. |
| 2 · Seguimiento | Fluidez y red: medir movimiento sostenido, giros, colisiones, apuntado y respuesta al lanzar con latencia real. La velocidad actual se conserva por ahora; el ajuste fino no bloquea el avance a clases y lobbies. Corregir según mediciones antes de agregar predicción/reconciliación. | Registrar latencia y pasos aceptados/rechazados; probar dos equipos con demoras de 0/80/150 ms y jitter. Definir una tolerancia de respuesta con pruebas de juego. |
| 3 · Próximo sistema | Clases y contrato de combate PvP: catálogo ampliable de clases AO20, sin limitarse a los cuatro ejemplos; equipo visible en el avatar y hechizos predeterminados, vida/maná, defensa y resistencias, permisos e intervalos. Ataque físico a distancia para el Cazador. | Cada preset funciona en servidor; equipo, costes y efectos se aplican una sola vez. El Cazador puede completar un duelo sin magia y el servidor rechaza hechizos ajenos a la clase. Valores iniciales documentados, con balance fino posterior. |
| 4 | Bot de arena, después de las clases: rival activable para probar presets, con movimiento, ataques, hechizos permitidos, pociones y dificultad básica. Usa las mismas reglas e intervalos del servidor. | Una persona puede completar y repetir un duelo; el bot usa una clase terminada y no gasta ni obtiene recursos fuera de las reglas. Su lógica queda preparada para incorporarla al lobby. |
| 5 | Partida y lobby: crear/unirse, elegir clase/preset antes de empezar, activar el bot cuando falta un rival, estado esperando/listo, inicio, aparición, victoria/derrota, revancha, salida y desconexión. Aislar cada lobby en el servidor. | Dos lobbies simultáneos no comparten daño, jugadores ni eventos; una desconexión resuelve la partida sin dejarla trabada. Definir el reemplazo del bot por otro humano entre partidas. |
| 6 | Sesión privada en servidor remoto WSS: despliegue del dedicado, acceso privado, logs y recuperación ante reinicio; dejar de depender del servidor de la PC para probar con otros equipos. | Se entra desde dos equipos sin usar localhost, no se amplía la audiencia sin autorización y se puede diagnosticar una desconexión. Prepararlo antes si hace falta para las pruebas de latencia del paso 2. |
| 7 | Web, cuentas y persistencia: registro/login, recuperación de acceso, perfiles/resultados y permisos privados. Base de datos y autenticación administrada, con validación de sesión también en el dedicado. | La cuenta conecta la sesión web con el jugador correcto; un cliente no puede escribir estadísticas/resultados ajenos. El acceso privado se mantiene hasta autorizar otra audiencia. |
| 8 | Diseño propio y balance: sustituir arte/distribución, perfiles finales, legibilidad, sonidos y ajustes con duelos repetibles. | El rediseño conserva controles y estados validados; se evalúan resultados de partidas, no sólo capturas. |

## Clases y presets dentro del punto 3

1. Relevar el catálogo de clases de la base AO20 y sus dependencias, sin limitarlo a Mago, Clérigo, Bardo y Cazador, que fueron ejemplos. Incorporar todas las clases que podamos sostener con sus mecánicas reales, empezando por familias mágicas, híbridas y físicas; las especialidades que requieran sistemas adicionales se habilitan cuando esos sistemas funcionen. Cada preset reúne hechizos permitidos, equipo inicial visible en el personaje (vestimenta/armadura, armas, escudo y casco según corresponda), iconos del inventario y atributos efectivos, incluyendo vida/maná y modificadores de daño, defensa y resistencia que se implementen. Los valores iniciales son de prueba, no balance final.
2. Aplicar y validar esos perfiles en el servidor. El cliente solicita un ID de preset; no decide sus propios atributos, equipo ni permisos. El Cazador necesita arco/ataque a distancia e intervalos funcionales: esconder el libro de hechizos no alcanza para convertirlo en una clase jugable. Su política de pociones, recuperación y munición debe definirse explícitamente.
3. Usar primero un selector de preset de prueba; después conectar la elección al lobby del punto 5, con presentación del equipo/hechizos y confirmación antes de iniciar. Cambiar de clase se permite entre partidas, con un reinicio controlado por el servidor; no puede servir para curarse o cambiar equipo en medio del duelo. El bot del punto 4 usa esos mismos perfiles y restricciones.

Una clase sólo se considera lista cuando su equipo modifica realmente sus estadísticas y se ve en el avatar; la vestimenta común actual no representa equipo de clase. Los objetos del preset se validan en servidor, incluso si se permiten reordenar visualmente en el inventario.

No hace falta implementar creación de personajes persistentes, niveles ni inventario completo para estos presets de arena. Sí hace falta aplicar realmente las propiedades del equipo que se muestren en la interfaz. La elección exacta de hechizos y objetos se define al implementar los perfiles, reutilizando datos AO20 disponibles y documentando las adaptaciones.

## Límites y dependencias

- Ordenar las dos pociones de provisión es una preferencia visual local, guardada por dispositivo. Inventario real con cantidades, equipo, comercio y persistencia de personaje es otro sistema; debe ser autoritativo antes de que esos objetos tengan valor de juego.
- La disposición y legibilidad de la interfaz se corrigen durante todo el trabajo. El cambio completo de identidad gráfica puede esperar hasta estabilizar controles y estados.
- No agregar PvE, progresión, mundo persistente o más hechizos por cantidad antes de completar una partida PvP repetible.

## Flujo de cambios

Una rama por tarea creada desde el `Alpha` actualizado y un PR cuya base sea directamente `Alpha`. Probar la rama con servidor y clientes de la misma revisión. Integrarla cuando ese cambio esté validado; el siguiente cambio parte del nuevo `Alpha`. No hace falta acumular varios PR ni esperar a terminar toda la etapa Alpha. No usar otra rama de trabajo como base salvo que se acuerde una dependencia explícita.

## Cierre de esta tanda

Antes de iniciar las clases, validar la cadencia moderadamente más rápida del PR actual, documentada en [ACTION_INTERVALS.md](ACTION_INTERVALS.md), e integrar esa tanda en Alpha. Las clases tendrán un PR independiente desde la base integrada, sin apilarlas sobre este PR abierto. Costos iniciales y límites de la futura web con cuentas: [HOSTING_BUDGET.md](HOSTING_BUDGET.md).
