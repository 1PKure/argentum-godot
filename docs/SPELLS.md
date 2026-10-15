# Hechizos y Lanzar

Esta entrega continúa la interfaz validada de `work/ao20-combat-ui`. No integra la prueba descartada de `work/pvp-spells`. Usa recursos y datos originales de AO20 para probar el flujo clásico dentro de la arena Godot.

## Controles

- Manual: abrir Hechizos, seleccionar una fila, pulsar Lanzar y hacer clic sobre un personaje. Seleccionar o apuntar no gasta maná.
- Accesos: 1 Dardo Mágico, 2 Flecha Mágica, 3 Curar Heridas Leves, 4 Curar Heridas Graves. El número selecciona el hechizo y activa directamente el cursor. El clic define el objetivo.
- Arrastrar una fila sobre un casillero de la barra para asignarla a 1–9/0. Se conserva la asignación en `user://spell_hotkeys.cfg` (almacenamiento local del navegador en web).
- Escape o clic derecho cancela el cursor. WASD permite caminar mientras se apunta. CTRL conserva el golpe físico y no consume maná.

## Datos reutilizados

| ID | Hechizo | Maná | Efecto base de vida |
| --- | --- | --- | --- |
| 1 | Dardo Mágico | 10 | Daño aleatorio 5–10 |
| 2 | Flecha Mágica (PVP) | 20 | Daño aleatorio 10–20 |
| 12 | Curar Heridas Leves | 5 | Curación aleatoria 5–20 |
| 13 | Curar Heridas Graves | 60 | Curación aleatoria 20–40 |

`SpellCatalog` lee nombre, descripción, palabras mágicas, coste y rangos del `Hechizos.dat` original. No se portó el código Visual Basic: el servidor Godot resuelve este subconjunto. `intervalos.ini` aporta 1230 ms entre hechizos y 800 ms entre golpe y hechizo en ambas direcciones. El golpe conserva su intervalo de 750 ms.

Los efectos, palabras mágicas y sonidos se muestran después de la confirmación del servidor. Curar Heridas Leves no define FXgrh en el DAT; se presenta con el FX de curación 9. Su icono de origen apunta a una celda vacía del atlas público, por lo que se muestra el icono de curación azul GRH 74686 del mismo atlas. Son adaptaciones visuales explícitas; no alteran los datos ni las reglas.

Procedencia y hashes: `assets/argentum/source/data/spells_sources.json`.
Datos y gráficos: [ao-org/Recursos, commit 89615f3](https://github.com/ao-org/Recursos/tree/89615f34162d9fa0bf0fae4242cd6639edbf772f).
Intervalos: [ao-org/argentum-online-server, commit 9d381f2](https://github.com/ao-org/argentum-online-server/tree/9d381f280c10b680cf1f84be5372f8c1dce42840).
Se mantienen los avisos y la licencia de los recursos en `assets/argentum/interface/ao20/`.

## Resolución y alcance

El servidor determina al lanzador por su conexión. Valida que esté vivo, que el hechizo pertenezca al libro, que exista un objetivo vivo dentro de la arena, el maná y los intervalos. El daño requiere un rival; la curación admite al propio personaje. Una solicitud repetida no vuelve a gastar recursos. Un rechazo no consume maná ni produce efectos visuales. Una curación válida sobre vida completa puede consumir maná con efecto real cero.

Se admiten objetivos en toda la arena visible de 20×12. No se añadió un alcance arbitrario ni una regla de línea de visión; falta portar la visión y las reglas completas de mapas de AO. Las estadísticas siguen siendo las del prototipo (100 vida/100 maná), sin clases, skills, equipo, resistencia, estamina, meditación ni multiplicadores. Tampoco incluye estados, invocaciones, catálogo completo, bot o lobbies. PvE está fuera del alcance acordado.

`PlayerNetwork` no cambia su tabla de RPC. `SpellNetwork` agrega un protocolo separado con comprobación de versión. Si el servidor es anterior, el cliente deshabilita Lanzar y explica que debe actualizarse. No debe probarse magia manteniendo abierto el servidor viejo.

## Validación

`tests/ao_spell_smoke.gd` comprueba datos originales, costes, daño/curación, intervalos, repetición, muertes, objetivos inválidos, apuntado y conversión de coordenadas dentro del marco escalado.

`tests/ao_spell_network_client.gd` usa dos clientes y el servidor WebSocket real. El cliente gráfico pulsa los botones, genera teclas y clics, arrastra un hechizo, camina mientras apunta y comprueba vida, maná, efectos, consola, CTRL y desconexión. El segundo cliente comprueba los resultados remotos y lanza un hechizo de vuelta. La misma prueba se ejecuta con el PCK de exportación.

La validación automatizada usa Godot 4.7.2 en Linux. La sensación del movimiento y la interacción final en Windows/web deben confirmarse en el equipo de juego con el servidor WSS local.
