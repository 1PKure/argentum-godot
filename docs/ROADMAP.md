# Prioridades de la arena PvP

Base integrada: `Alpha`, con PR7 fusionado. Sólo PvP; sin inversión monetaria, sin servicios de pago y sin cuentas obligatorias.

| Orden | Trabajo | Criterio de cierre |
| --- | --- | --- |
| Hecho | Interfaz AO20, consola, Lanzar/macros, recuperación, efectos siguiendo al personaje, cámara e intervalos. | Conservar las regresiones de dos clientes. |
| 1 · Actual | Clases y presets. Nueve perfiles de prueba con equipo visible, estadísticas efectivas, permisos de hechizos y Cazador físico a distancia. | Validación del servidor y del selector en dos clientes; prueba de juego y merge del PR de clases. Especialidades avanzadas y balance fino quedan documentados. |
| 2 · Siguiente | Lobby PvP de invitados, sin cuentas ni DB: crear/unirse, elegir clase, listo, iniciar, victoria/derrota, revancha y salir. | Dos lobbies simultáneos aislados: sin daño, jugadores o eventos cruzados. Una desconexión resuelve la partida. Usar el preset validado, bloqueado durante el duelo. |
| 3 | Bot opcional cuando falta un jugador. | Usa clases, recursos e intervalos del servidor; permite completar y repetir un duelo. Se integra al lobby sin rehacer el combate. |
| 4 | Pulido de movimiento/red y combate con duelos repetibles, latencia y giros; proyectil del arco, señales de golpe y especialidades, incluyendo apuñalada del Asesino desde atrás. | Evaluar fluidez real. La velocidad de movimiento actual se conserva por ahora. |
| 5 | Diseño propio de interfaz y balance. | Mejorar legibilidad, sonido y diferencias entre clases con partidas reproducibles. |
| Opcional | Acceso remoto gratuito, cuentas y persistencia sólo si tienen utilidad y una alternativa gratuita adecuada. | Ningún cargo, nueva contratación ni ampliación de visibilidad. Se puede seguir sin cuentas y con dedicado local. |

Los presets actuales y sus fórmulas adaptadas están en [CLASSES.md](CLASSES.md). No equivalen al port completo de las especialidades de AO20. El orden local de pociones no es un inventario persistente con propiedad y comercio. No se añade PvE, progresión o mundo persistente.

Una rama por tarea desde `Alpha` actualizado; PR directamente a `Alpha`. Servidor y clientes deben usar la misma revisión. Se valida e integra cada tanda antes de iniciar la siguiente; no se apilan PR sobre ramas abiertas.

La web permanece privada. Se descarta cualquier alternativa de pago: [política de costo cero](HOSTING_BUDGET.md).

Durante la práctica se cambia libremente de preset. El lobby definirá selección previa, cuenta regresiva y reinicio de ronda; ese flujo todavía no está implementado. El equipo es movible/equipable en inventario autoritativo de sesión.
