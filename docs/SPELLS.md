# Hechizos y Lanzar

La arena continúa la interfaz validada de AO20, sin incorporar la prueba retirada de `work/pvp-spells`. El libro importa las 213 entradas de Hechizos.dat y habilita 39 que tienen resolución de servidor. La lista exacta, con cada dependencia pendiente, está en [SPELL_CATALOG.md](SPELL_CATALOG.md).

## Controles

- Manual: abrir Hechizos, seleccionar una fila, pulsar Lanzar y hacer clic sobre un personaje. Seleccionar o apuntar no gasta maná.
- Accesos iniciales: 1 Dardo Mágico, 2 Flecha Mágica, 3 Curar Heridas Leves y 4 Curar Heridas Graves. El número selecciona y activa el cursor.
- Arrastrar una fila habilitada sobre un casillero para asignarla a 1–9/0. Se conserva en user://spell_hotkeys.cfg.
- Escape o clic derecho cancela. WASD permite caminar mientras se apunta. CTRL golpea sin maná. M medita; Q/E usan pociones.
- Buscar por nombre o ID filtra el libro. Ver catálogo completo permite consultar las entradas pendientes: muestran su motivo y no habilitan Lanzar ni asignación a macros.

## Resolución y recursos

El servidor identifica al lanzador por su conexión y valida personaje vivo, libro disponible, objetivo, maná, intervalo global 1230 ms, cruce golpe/magia 800 ms y cooldown individual. Rechazos y solicitudes repetidas no gastan recursos. Daño requiere rival; curación y remover admiten al propio jugador. Una cura directa sobre vida completa puede gastar maná con efecto cero. Las raíces bloquean caminar; permiten lanzar remover o beber. Los efectos periódicos usan valores y tiempos de EffectsOverTime.dat.

Los objetivos se admiten dentro de toda la arena 20×12. Falta portar visión, línea de visión y las reglas completas de mapas de AO. El perfil de prueba de 500 vida/3000 maná no representa una clase ni balance final. No aplica requisitos de clase, skills, estamina, equipo ni multiplicadores. Los hechizos cuyo efecto depende de esos sistemas quedan pendientes. Invocaciones, bot y lobbies siguen pendientes; PvE está fuera del alcance acordado.

PlayerNetwork conserva su tabla RPC. SpellNetwork usa un protocolo separado, versión 2, y comprueba soporte. Un servidor anterior a ese protocolo deshabilita Lanzar/recuperación y muestra una instrucción de actualización. Para probar cada cambio hay que actualizar y reiniciar el servidor desde la misma rama/revisión que el cliente; la compatibilidad del protocolo no garantiza reglas idénticas entre revisiones.

## Procedencia y adaptaciones visuales

Datos, iconos, FX y audio proceden de [ao-org/Recursos, commit 89615f3](https://github.com/ao-org/Recursos/tree/89615f34162d9fa0bf0fae4242cd6639edbf772f). Los intervalos y reglas consultadas proceden de [ao-org/argentum-online-server, commit 9d381f2](https://github.com/ao-org/argentum-online-server/tree/9d381f280c10b680cf1f84be5372f8c1dce42840). No es un port del servidor entero. Se conservan los avisos de los recursos en assets/argentum/interface/ao20/. Hashes y excepciones están en assets/argentum/source/data/spells_sources.json.

Curar Heridas Leves usa FX9 y el icono azul GRH74686 porque su DAT no define FX y apunta a un icono vacío. Aliento de Dragón no define icono y muestra el de fuego GRH74714. Implosión guarda directamente el GRH12834 en el DAT: el adaptador usa FX4, que refiere a esa misma animación. Siete sonidos referenciados no existen en el repositorio público de la revisión y usan el sonido16 como sustituto explícito. WAV113 se decodificó de ADPCM a PCM para importación en Godot; se conserva el original en audio/originals/113.wav.source. La meditación usa el FX de nivel máximo120 disponible; ver [RECOVERY.md](RECOVERY.md).

El render de impactos alinea el último píxel visible de cada frame con los pies del avatar. Compensa el margen transparente, conserva OffsetX y sustituye OffsetY del render original por esta alineación. No modifica las imágenes ni FXs.ini; la meditación conserva su presentación validada. Los impactos y resultados flotantes acompañan al objetivo interpolado; las palabras acompañan al lanzador, incluso si se mueven en sentidos distintos. Son efectos de personaje; un futuro hechizo de área fija requerirá su propia presentación sobre terreno.

## Validación

Pruebas de datos y servidor: ao_spell_smoke.gd y arena_recovery_smoke.gd. Recursos reales: arena_assets_smoke.gd. Movimiento y cámara: movement_smoke.gd y camera_movement_smoke.gd. Interacción real con servidor y dos clientes: arena_network_client.gd, ejecutado también sobre el PCK exportado. Comprueba clics, búsqueda, arrastre, macros, daño, curas, pociones, meditación/FX, remo, cámara, CTRL, muerte, reaparición y resize. La validación automatizada usa Godot 4.7.2 en Linux; falta confirmar la sensación y la interacción de esta entrega en Windows/web.
