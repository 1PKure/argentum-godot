# Interfaz de combate AO20

El HUD conserva recursos originales de AO20, consola, Inventario/Hechizos, minimapa y barras confirmadas de vida/maná. La base de diseño actual es 1280×800. Ocupa todo el viewport con controles a escala uniforme y amplía el área de juego en ventanas más anchas; no requiere 1920×1080.

La cámara sigue al avatar interpolado dentro de game_area. No mueve el HUD. El exterior decorativo oscurecido evita franjas negras al seguir al jugador cerca del borde; la línea marca los límites autoritativos originales de 20×12 y no agrega casillas caminables.

Los FX se anclan por la base a los pies y se dibujan por delante del cuerpo. El impacto y el resultado flotante siguen al objetivo interpolado; las palabras siguen al lanzador. Son referencias a esos avatares concretos: desconectar o reutilizar un ID no deja un efecto atado a otro personaje. El nombre y las barras se mantienen encima de la meditación, reducida un 30% y con opacidad 72% para dejar visible el avatar.

El inventario permite arrastrar las dos provisiones de arena a casilleros vacíos o intercambiarlas. El orden se guarda por dispositivo en `user://arena_inventory.cfg`; un clic usa la poción que ocupa ese casillero y un arrastre nunca la consume. No representa todavía un inventario autoritativo con cantidades o equipo. Q/E conservan sus acciones al reordenar.

El libro incorpora búsqueda, catálogo completo y accesos por arrastre. Ver [SPELLS.md](SPELLS.md) y [SPELL_CATALOG.md](SPELL_CATALOG.md) para los 39 habilitados y los motivos de las entradas pendientes. Las pociones y la meditación se explican en [RECOVERY.md](RECOVERY.md). Los botones y scrollbars no toman foco de teclado. El campo de búsqueda sí captura texto mientras se escribe; Enter libera ese foco.

La consola muestra eventos de hechizos/recuperación confirmados, rechazo al solicitante, entradas/salidas, vida/maná y muerte. Mantiene filtros, máximo 200 mensajes y nombres como texto literal. Los golpes físicos conservan un mensaje genérico de pérdida de vida porque su protocolo aún no informa autoría.

## Prueba desde Windows

1. Cerrar Godot, clientes y servidor anterior.
2. GitHub Desktop: Fetch origin, Current branch work/alpha-combat-feedback y Pull origin si aparece. Después de integrar el PR, usar Alpha actualizado.
3. Reabrir project.godot y esperar la importación. F5 prueba el proyecto desde el editor. Para web, ejecutar tools/Start-PrivateWebTest.cmd y conectar a wss://127.0.0.1:7777.
4. Abrir dos clientes y acercarse usando el minimapa. Probar Lanzar, macros, buscar Apocalipsis y asignarlo por arrastre.
5. Arrastrar la roja a un casillero vacío, intercambiarla con la azul y cancelar un arrastre fuera de la grilla: no deben cambiar los recursos. Usarlas con clic desde sus nuevas posiciones. Probar Q/E y M; ambas pociones permiten seguir meditando. Caminar interrumpe la meditación. Comprobar cámara y puntero después de caminar.
6. Probar parálisis/remo, morir y usar Reaparecer. Al desconectar/reconectar no deben quedar avatar, FX o estado de la sesión anterior.
7. Curarse y caminar antes de que termine la animación: FX y resultado deben seguir al personaje; las palabras de un hechizo dirigido a otro jugador deben seguir a quien lo lanzó.

## Rediseño posterior

Arte y distribución viven en CombatHUD y SpellSlotButton; selección/apuntado en SpellTargetingController; reglas y recuperación en el servidor. Cambiar texturas, colores o distribución no exige rehacer las reglas de hechizos. Cambiar la forma de apuntar o los controles sí exige adaptar y validar interacciones.
