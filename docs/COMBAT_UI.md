# Interfaz de combate de la arena

El HUD usa paneles originales de Godot en azul noche, marfil y dorado, consola, Inventario/Hechizos, minimapa y barras confirmadas de vida/maná. Las pociones e iconos de hechizos usan SVG propios. La base de diseño actual es 1280×800. Ocupa todo el viewport con controles a escala uniforme y amplía el área de juego en ventanas más anchas; no requiere 1920×1080.

La cámara sigue al avatar interpolado dentro de game_area. No mueve el HUD. El exterior decorativo oscurecido evita franjas negras al seguir al jugador cerca del borde; la línea marca los límites autoritativos originales de 20×12 y no agrega casillas caminables.

Los nuevos FX vectoriales de hechizos se anclan por su origen visible a los pies y se dibujan por delante del cuerpo. El impacto y el resultado flotante siguen al objetivo interpolado; las palabras siguen al lanzador. Son referencias a esos avatares concretos: desconectar o reutilizar un ID no deja un efecto atado a otro personaje. El nombre y las barras se mantienen encima de la meditación compacta azul/dorada, abierta para dejar visible el avatar.

El inventario muestra provisiones y todas las piezas del preset. Arrastrar mueve/intercambia; clic equipa/desequipa o usa una poción. El servidor valida objetos y revisiones; la marca E identifica el equipo actual. El orden dura la sesión y se reconstruye al cambiar de preset. Q/E mantienen sus acciones. Ver [CLASSES.md](CLASSES.md).

El libro incorpora búsqueda, catálogo completo y accesos por arrastre. Ver [SPELLS.md](SPELLS.md) y [SPELL_CATALOG.md](SPELL_CATALOG.md) para los 39 habilitados y los motivos de las entradas pendientes. Las pociones y la meditación se explican en [RECOVERY.md](RECOVERY.md). Los botones y scrollbars no toman foco de teclado. El campo de búsqueda sí captura texto mientras se escribe; Enter libera ese foco.

La consola muestra eventos de hechizos/recuperación confirmados, rechazo al solicitante, entradas/salidas, vida/maná y muerte. Mantiene filtros, máximo 200 mensajes y nombres como texto literal. Los golpes físicos conservan un mensaje genérico de pérdida de vida porque su protocolo aún no informa autoría.

## Prueba desde Windows

1. Cerrar Godot, clientes y servidor anterior.
2. GitHub Desktop: Fetch origin, Current branch work/alpha-combat-feedback y Pull origin si aparece. Después de integrar el PR, usar Alpha actualizado.
3. Reabrir project.godot y esperar la importación. F5 prueba el proyecto desde el editor. Para web, ejecutar tools/Start-PrivateWebTest.cmd y conectar a wss://127.0.0.1:7777.
4. Abrir dos clientes y acercarse usando el minimapa. Probar Lanzar, macros, buscar Apocalipsis y asignarlo por arrastre.
5. Arrastrar la roja a un casillero vacío, intercambiarla con la azul y cancelar un arrastre fuera de la grilla: no deben cambiar los recursos. Usarlas con clic desde sus nuevas posiciones. Probar Q/E y M; ambas pociones permiten seguir meditando. Caminar interrumpe la meditación. Comprobar cámara y puntero después de caminar.
6. Probar parálisis/remo, morir y usar Menú → Reaparecer. Al desconectar/reconectar no deben quedar avatar, FX o estado de la sesión anterior.
7. Curarse y caminar antes de que termine la animación: FX y resultado deben seguir al personaje; las palabras de un hechizo dirigido a otro jugador deben seguir a quien lo lanzó.

## Rediseño posterior

Arte y distribución viven en CombatHUD y SpellSlotButton; selección/apuntado en SpellTargetingController; reglas y recuperación en el servidor. Cambiar texturas, colores o distribución no exige rehacer las reglas de hechizos. Cambiar la forma de apuntar o los controles sí exige adaptar y validar interacciones.

La web precarga `wss://127.0.0.1:7777`: iniciar el `.cmd` y pulsar Conectar. El desarrollo nativo conserva WS; una dirección remota configurada explícitamente se respeta. La meditación conserva el anclaje y tamaño ya validados.

## Lectura y movimiento de inventario

El nombre de cada personaje se muestra debajo de sus barras, sin sufijos de depuración, para dejar libre la zona de palabras mágicas. El inventario no contiene el resumen permanente de clase/equipo: los objetos conservan tooltip y marca de equipado. Mantener el botón derecho y arrastrar mueve/intercambia; el izquierdo selecciona/bebe o equipa. Esc, modales, pérdida de foco, cambio de inventario y desconexión cancelan movimientos pendientes. Las flechas confirmadas reproducen el audio adjunto `Arrow hit 2.wav` al impacto visual; preparar, cancelar o recibir rechazo de intervalo no reproduce impacto.

La cabecera suma **Skins**: vistas previas, hitos de victorias y selección de atuendo sin alterar equipo. La preparación del bot muestra **3, 2, 1, ¡YA!** con tweens/tonos; ambos personajes quedan bloqueados por el servidor hasta comenzar. Véase `BOTS.md` para progreso local y cancelaciones.

## Pie compacto

Se retiraron los cuatro botones Meditar, Vida, Maná y Usar. El pie muestra recursos, estados y **Menú**; Reaparecer vive dentro del menú cuando el personaje está muerto. Se conservan M, Q/E, Espacio mantenido, clic en pociones y macros sin cambiar la pestaña o el apuntado. `hud_layout_client.gd` valida menú/reaparición/meditación y cuatro resoluciones; `potion_use_client.gd` valida las pociones seleccionadas desde teclado.

## Arenas

**Menú → Arenas** abre los cuatro escenarios. El primer humano conectado puede elegir; el resto observa. El cambio reinicia la práctica para todos. Ver [ARENAS.md](ARENAS.md).

Ver [identidad visual y alcance de esta revisión](VISUAL_IDENTITY.md).
