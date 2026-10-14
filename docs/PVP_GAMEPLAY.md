# Base de gameplay PvP

Alcance acordado: PvP entre dos jugadores y, después, un bot opcional cuando falte rival en el lobby. PvE queda fuera del alcance actual. Esta entrega agrega la primera base de hechizos al juego Godot existente; los lobbies, el bot y las reglas de revancha son los siguientes hitos.

## Qué se reutiliza

- `PlayerState`: vida, maná, daño, curación y muerte como fantasma.
- `PlayerRegistry`: actores, posiciones y validación autoritativa.
- `PlayerNetwork`: solicitudes por RPC e identidad del emisor obtenida del transporte.
- `PlayerAvatar`: sprites AO, barras e indicador del objetivo.

Los hechizos se definen como recursos `.tres` en `shared/gameplay/spells`. El catálogo resuelve sus IDs, `SpellRules` valida los objetivos y `PlayerRegistry.try_cast_spell` aplica el resultado. El futuro bot llamará esta misma función en el servidor; no tendrá una segunda implementación de daño, maná o recarga.

## Controles y reglas de esta iteración

| Control | Acción |
| --- | --- |
| WASD | Movimiento existente por casillas |
| Ctrl | Golpe frontal existente |
| 1 / 2 | Elegir Descarga / Curar heridas |
| Lanzar o E | Preparar un lanzamiento manual; después hacer clic sobre un jugador |
| Combate o C | Activar/desactivar los lanzamientos con clic directo |
| Esc o clic derecho | Salir del apuntado y del modo combate |

El modo manual termina después de un lanzamiento aceptado. Un objetivo inválido mantiene el apuntado para corregirlo. En combate, el modo permanece activo entre lanzamientos. Los clics sobre la interfaz no apuntan al mundo. Sólo se permite una solicitud pendiente por cliente; el servidor sigue validando todos los intentos.

Valores iniciales de prueba, editables en los recursos:

| Hechizo | Efecto | Maná | Alcance | Recarga |
| --- | --- | --- | --- | --- |
| Descarga | 20 de daño a otro jugador | 15 | 6 casillas | 750 ms |
| Curar heridas | Hasta 25 de vida, incluido uno mismo | 12 | 6 casillas | 750 ms |

La recarga es compartida entre hechizos, de modo que cambiar de selección no la evita. El alcance usa distancia por casillas en ocho direcciones; los obstáculos y sus esquinas bloquean la línea de visión. Un fallo no consume maná ni inicia una recarga. Curar no resucita ni consume recursos sobre un objetivo con vida completa. El daño letal conserva el fantasma existente.

Los efectos son feedback de un resultado ya confirmado por el servidor. Esta iteración no añade regeneración, pociones, resurrección ni balance definitivo. Para reiniciar un personaje en esta prueba se reconecta el cliente.

## Probar desde GitHub Desktop

1. Detener el servidor anterior.
2. **Fetch origin**, seleccionar `work/pvp-spells` en **Current branch** y hacer **Pull origin** si aparece.
3. Abrir **Repository → Show in Explorer → tools → Start-PrivateWebTest.cmd**. El lanzador importa las clases y recursos antes de iniciar el servidor WSS de la rama actual.
4. Abrir el [cliente Web PvP privado](https://argentum-arena-mati.smartpine8.chatgpt.site/pvp/) que corresponde a esta rama y conectar dos ventanas a `wss://127.0.0.1:7777`.
5. Acercar los personajes: los spawns originales están a 11 casillas y los hechizos llegan a 6.
6. Probar Descarga con Lanzar, curar el personaje herido haciendo clic sobre él y repetir con Combate activado. Comprobar maná, recarga, objetivo propio, falta de alcance y muerte.

Cliente y servidor deben usar esta versión juntos: los nuevos RPC cambian la firma de `PlayerNetwork`. El cliente Web anterior corresponde al servidor anterior. Ambos clientes Web de una prueba deben abrir la misma ruta/versión.

## Validación y límites

Godot 4.7.2 ejecutó 32 comprobaciones de reglas y controles, además de una prueba con servidor y dos clientes reales (11 comprobaciones): movimiento RPC, lanzamiento manual, combate con clic, daño, curación, efectos, maná y rechazo de objetivos. Las regresiones de conexión/cancelación y de TLS también se ejecutaron. El paquete Web se genera con `--export-pack Web` y reutiliza el motor Web 4.7.2 de la exportación entregada.

La comprobación visual y de apuntado físico en el navegador Windows queda pendiente. Las pruebas automatizadas usan el motor nativo y los manejadores reales de los controles, no un navegador.

## Próximos hitos

1. Definir inicio, final y revancha del duelo; aislar cada lobby y validar que los objetivos pertenezcan a la misma partida.
2. Crear/unirse a un lobby de dos plazas y añadir el bot sólo cuando falte rival.
3. Añadir el resto del repertorio y sus reglas de uso sobre la base compartida.
4. Medir y pulir movimiento, apuntado, latencia y feedback. El input actual envía pasos cada 140 ms y la interpolación visual dura 120 ms; ese desfase se revisará junto con la cadencia del servidor de 120 ms. Todavía no se afirma que la fluidez esté resuelta.

