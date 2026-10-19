# Argentum · Arena PvP

Prototipo multijugador real en Godot 4.7 Standard, con cliente web y dedicado autoritativo por WebSocket/WSS. Se concentra en duelos 1v1 y práctica opcional contra bot. PvE está descartado.

## Probar desde GitHub Desktop

1. Fetch origin → elegir `work/arena-lobbies` → Pull origin.
2. Cerrar el dedicado anterior y ejecutar `tools/Start-PrivateWebTest.cmd`.
3. Recargar la [web privada](https://argentum-arena-mati.smartpine8.chatgpt.site) con Ctrl+F5 y conectar. `wss://127.0.0.1:7777` sigue precargado.
4. Crear una sala con nombre/arena, o unirse a una disponible. Cada sala tiene dos plazas.
5. Elegir clase, ver el preset y equipar skins. Si falta un humano, añadir un bot y elegir su clase.
6. Ambos humanos marcan Listo; en práctica, basta el dueño con bot habilitado. Cuenta 3→2→1→¡YA!, combate, resultado y revancha.
7. Menú → Salir de la sala vuelve al directorio conservando conexión. Desconectar está en el directorio.

Cliente y dedicado deben usar la misma revisión y **protocolo 17**. `tools/Start-PrivateWebTest.cmd` importa el proyecto antes de iniciar WSS. [Guía WSS](docs/WEB_TEST.md).

## Salas y escenarios

Cada lobby posee PlayerRegistry, ArenaPracticeBot y ArenaSession propios. Snapshots, movimiento, daño, estadísticas y efectos sólo llegan a sus participantes. Se rechazan salas llenas, acciones ajenas, versiones antiguas y repeticiones. Salir/transmitir anfitrión y eliminar salas vacías se resuelve en servidor.

Bosque, Desierto, Lava y Sala de Duelos conservan pisos interiores y colisiones 20×12, cuatro obstáculos simétricos y spawns separados. El anfitrión puede cambiar escenario durante preparación/resultado. Cambiar escenario o clase invalida Listo; no se permite durante el duelo. El bot se retira al entrar otro humano. Una ronda interrumpida no concede premios.

[Flujo de lobbies y validación](docs/LOBBIES.md) · [Escenarios](docs/ARENAS.md).

## Combate y presentación

Nueve presets AO20 con estadísticas, equipo visible en inventario y macros por clase. Trabajador/Pirata/Ladrón quedan excluidos. Balance y dificultad del bot aprobados conservados. [Clases y balance](docs/CLASSES.md) · [Intervalos](docs/ACTION_INTERVALS.md).

Seleccionar hechizo → Lanzar → objetivo, o macro 1–0 → objetivo. Cazador: CTRL/3 prepara el arco y clic dispara con intervalo autoritativo. M medita; Q/E recuperan; clic selecciona/bebe y Espacio usa la poción seleccionada, mantenido para repetir. Macros conservan pestaña/apuntado; arrastre derecho reorganiza objetos. Equipo se equipa/desequipa con clic. [Hechizos](docs/SPELLS.md) · [Recuperación](docs/RECOVERY.md).

HUD propio azul noche/marfil/dorado, consola inferior, barras y casilleros propios; todas las ventanas, incluida clases/presets, usan el mismo tema. Pociones e iconos SVG originales, props detallados y lava exterior de escala fija. Efectos originales para los 39 hechizos disponibles y meditación compacta azul/dorada. Se conservan anclaje, seguimiento, flecha/sangre/audio y reglas. Personajes, equipo y skins mantienen animaciones AO20. [Identidad visual y límites](docs/VISUAL_IDENTITY.md).

La cámara sigue al personaje y el zoom 1×/2× mantiene escala de píxel entera. Base de diseño 1280×800 y revisión en cuatro resoluciones. La consola sólo muestra eventos propios; el servidor omite maná rival y costes privados. [Interfaz](docs/COMBAT_UI.md) · [Movimiento](docs/MOVEMENT.md).

## Skins, acceso y presupuesto

Skins por clase a 1/3/5 victorias reales contra bot, sin duplicar recompensas por ronda. Selección y progreso se guardan localmente en el navegador, sin cuentas/DB ni sincronización entre dispositivos. Cambiar atuendo no altera equipo ni estadísticas. [Bot](docs/BOTS.md).

Sólo opciones gratuitas. La web mantiene acceso privado y necesita el dedicado local encendido. Hosting independiente, cuentas opcionales y especialidades avanzadas de clases quedan pendientes. [Presupuesto](docs/HOSTING_BUDGET.md) · [Prioridades](docs/ROADMAP.md).

## Recursos y pruebas

Se conservan procedencia y licencia AO20 en `assets/argentum/interface/ao20/` y datos de origen bajo `assets/argentum/source/`. Los nuevos SVG y FX son originales del proyecto.

Las pruebas de lobbies incluyen dos salas con cuatro clientes y práctica solo+bot. `tests/run_lobby_network.py` genera logs/resultados separados y rechaza errores de servidor/cliente. Los smoke cubren aislamiento, capacidad, permisos, Listo, cuenta, resultados, salida/reentrada, cambio de mapa/clase, progreso y navegación. La revisión visual de HUD/ventanas y efectos usa Godot nativo GL Compatibility; sensación/audio en navegador Windows siguen siendo parte de la prueba manual.
