# Prioridades de la arena PvP

Base integrada: `Alpha`, con clases/balance/HUD (PR8) y conexión dorada/blanca (PR9) fusionados. Sólo PvP; sin inversión monetaria, sin servicios de pago y sin cuentas obligatorias.

| Orden | Trabajo | Criterio de cierre |
| --- | --- | --- |
| Hecho | Interfaz AO20, consola, Lanzar/macros, recuperación, efectos siguiendo al personaje, cámara e intervalos. | Conservar las regresiones de dos clientes. |
| Hecho | Nueve clases/presets, equipo e inventario autoritativo, arco dirigido y balance base aceptado. | PR8 integrado y reglas conservadas. |
| 1 · Actual | Bot opcional para práctica a solas, con los nueve presets, combate y recuperación del servidor. | Activar/reiniciar/quitar; muerte detiene IA; desconectar al dueño o entrar otro humano elimina el bot; validación con dos clientes. |
| 2 · Siguiente | Lobby PvP de invitados, sin cuentas ni DB: crear/unirse, elegir clase, listo, iniciar, victoria/derrota, revancha y salir. Bot como rival opcional de la sala. | Dos lobbies simultáneos aislados: sin daño, jugadores o eventos cruzados. Una desconexión resuelve la partida. Usar el preset validado, bloqueado durante el duelo. |
| 3 | Pulido de movimiento/red y combate con duelos repetibles, latencia y giros; proyectil del arco, señales de golpe y especialidades, incluyendo apuñalada del Asesino desde atrás. | Evaluar fluidez real. La velocidad de movimiento actual se conserva por ahora. |
| 4 | Diseño propio de interfaz y balance. | Mejorar legibilidad, sonido y diferencias entre clases con partidas reproducibles. |
| Opcional | Acceso remoto gratuito, cuentas y persistencia sólo si tienen utilidad y una alternativa gratuita adecuada. | Ningún cargo, nueva contratación ni ampliación de visibilidad. Se puede seguir sin cuentas y con dedicado local. |

Los presets actuales y sus fórmulas adaptadas están en [CLASSES.md](CLASSES.md). No equivalen al port completo de las especialidades de AO20. El orden local de pociones no es un inventario persistente con propiedad y comercio. No se añade PvE, progresión o mundo persistente.

Una rama por tarea desde `Alpha` actualizado; PR directamente a `Alpha`. Servidor y clientes deben usar la misma revisión. Se valida e integra cada tanda antes de iniciar la siguiente; no se apilan PR sobre ramas abiertas.

La web permanece privada. Se descarta cualquier alternativa de pago: [política de costo cero](HOSTING_BUDGET.md).

Durante la práctica se cambia libremente de preset. El lobby definirá selección previa, cuenta regresiva y reinicio de ronda; ese flujo todavía no está implementado. El equipo es movible/equipable en inventario autoritativo de sesión.

La práctica con bot anterior al lobby está detallada en [BOTS.md](BOTS.md). La prioridad bot antes de lobby sigue el orden solicitado; no sustituye la futura implementación de salas.
