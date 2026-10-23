# Escenarios de la arena

Rama `work/arena-lobbies`, desde Alpha con PR10 integrado. Cliente y dedicado requieren **protocolo 24** y la misma revisión.

## Probar en Windows

1. GitHub Desktop: Fetch origin, elegir `work/arena-lobbies` y Pull origin.
2. Cerrar el dedicado anterior y ejecutar `tools/Start-PrivateWebTest.cmd`.
3. Recargar la web privada con Ctrl+F5 y conectar. WSS sigue precargado.
4. **Menú → Arenas**: el primer humano conectado es anfitrión y puede elegir. Los invitados ven las opciones deshabilitadas.
5. Cambiar escenario restaura posiciones, recursos, estados e inventario/equipo del preset; conserva clase y skin. Durante 600 ms el servidor bloquea movimiento/combate/recuperación. Interrumpir una ronda no concede premios.
6. Con bot activo se inicia una práctica nueva con su cuenta de tres segundos, sin adelantarla al terminar la transición del mapa.
7. Un segundo cliente recibe el escenario ya elegido y el bot se retira. Al desconectarse el anfitrión, el siguiente humano recibe el control.

| Arena | Terreno | Decoración y exterior |
| --- | --- | --- |
| Bosque | Césped AO20 conservado | Cuatro props simétricos y árboles exteriores |
| Desierto | Arena con grano y ondulaciones | Cactus, rocas exteriores |
| Lava | Plataforma de obsidiana y fisuras | Basalto, brasas y lava animada exterior; sin daño adicional |
| Sala de Duelos | Losas de piedra e insignia central | Columnas simétricas y antorchas exteriores |

Los cuatro escenarios conservan límites de 20×12, dos spawns (4,5 y 15,5), un pasillo central despejado y 240 casillas caminables conectadas. Los cuatro adornos interiores de cada mapa son transitables y no bloquean flechas o magia. scenery_cells conserva sus posiciones visuales y blocked_cells queda vacío; los límites exteriores y la ocupación por jugadores siguen activos. Minimap y vista previa conservan los adornos. No cambia el balance. Los recursos del Bosque conservan su atribución; los nuevos terrenos, props y shader son código original, sin assets descargados ni servicios pagos. Es arte funcional de prototipo; su acabado pertenece al futuro rediseño.

## Alcance

Cada sala tiene su propia arena y registro. El directorio permite Crear/Unirse, dos plazas, Listo, cuenta, resultado y revancha. La selección inicial usa este catálogo; cambiar escenario después requiere ser anfitrión y estar en preparación/resultado. Ver [LOBBIES.md](LOBBIES.md).

`ArenaSession` agrupa registro, bot, revisión y transición. El servidor valida pertenencia, anfitrión, escenario, revisión, nonce y tiempo. Los rechazos no reinician personajes. Publica el estado del mapa antes del snapshot; el cliente elimina avatares/efectos anteriores y reconstruye suelo, props y jugadores. La transición conserva cualquier bloqueo más largo del bot.

Cada sala tiene su propio PlayerRegistry/ArenaPracticeBot/ArenaSession y limita snapshots, movimiento, daño, efectos y resultados a sus participantes.

## Validación reproducible

`tests/arena_environment_smoke.gd`: conectividad, simetría, límites, permisos, nonces, revisiones, reset y bloqueo, relevo de anfitrión, reinicio del bot sin recompensa y navegación legal en los cuatro escenarios.

`tests/arena_environment_client.gd`: dedicado real y dos clientes del PCK exportado; selección con clics, entrada tardía, solicitud de invitado rechazada, mapas/minimapa/HUD, reset/limpieza, cámara/apuntado, cuatro resoluciones y transferencia de control. Prueba manual de sensación y audio en navegador Windows pendiente de revisión del usuario.
