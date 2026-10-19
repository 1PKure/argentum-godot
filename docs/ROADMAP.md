# Próximos PR del prototipo PvP

Alpha incluye clases/presets, combate manual/macros, pociones/meditación, cámara, bot calibrado, cuenta de ronda y skins por clase. Ese balance queda cerrado por ahora. PvE está descartado.

| Orden | Objetivo | Resultado comprobable |
| --- | --- | --- |
| 1 | Escenarios (implementado) | Bosque, Desierto, Lava y Sala de Duelos; selección sincronizada y reinicio válido. Rama `work/arena-environments`. |
| 2 | Lobbies 1v1 (en revisión) | Después de conectar: Crear/Unirse, nombre y capacidad de dos, arena al crear y cambio por anfitrión, clase, Listo de ambos, cuenta y duelo. Salas aisladas. |
| 3 | Interfaz propia (primera pasada implementada) | Presentación, lista de salas y HUD con base dorado/blanco, jerarquía limpia, controles, inventario/libro/macros, consola y opciones coherentes. |
| 4 | Efectos y gráficos (magia/meditación implementadas) | Renovar Descarga, Tormenta, fuego y curaciones primero; luego todos los demás. Conservar lectura, anclaje y tiempos; unificar escenarios, personajes y equipo. |

## Incluir con los lobbies

- Cada sala posee registro de jugadores, bot y estado propios. Snapshots, daño, movimiento, efectos y resultados sólo llegan a sus participantes; probar dos salas simultáneas con mapas distintos.
- Bot opcional sólo cuando falta el segundo humano; se retira al entrar otro jugador.
- Cambiar arena o clase en preparación invalida Listo. El inicio depende del servidor; no se permite cambiar mapa durante el duelo.
- Resultado, revancha, salida/desconexión durante espera, cuenta o combate; transferencia del anfitrión y limpieza de salas vacías.
- Rechazar salas llenas/eliminadas, acciones cruzadas entre salas y recompensas por abandonar/reiniciar una práctica.

## Pendientes adicionales

**Hosting del dedicado** para jugar sin mantener la PC de Mati encendida: evaluar sólo opciones gratuitas y WSS. La web actual conserva su audiencia privada. Cuentas y base de datos siguen siendo opcionales; los lobbies no las requieren.

**Especialidades de clase**, como la puñalada del Asesino desde atrás, después de estabilizar el flujo de duelos. Es una etapa distinta del balance numérico aprobado.

**Pruebas con jugadores y red real**: bot, lectura de efectos, movimiento/latencia, recuperación, resultados y rendimiento en navegador.
