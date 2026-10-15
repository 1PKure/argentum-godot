# Interfaz de combate AO20

Esta iteración parte de `work/web-export-alpha`, sin incorporar la prueba retirada de `work/pvp-spells`.

La interfaz usa los recursos originales de AO20: marco de 1024×768, consola superior, paneles Inventario/Hechizos y barras de vida/maná. Se adapta al espacio disponible conservando proporciones y toda la arena se presenta dentro del área de juego. El minimapa muestra posiciones reales y obstáculos.

Los botones y la barra de desplazamiento no toman foco de teclado. WASD y CTRL conservan sus acciones al cambiar de pestaña, seleccionar un hechizo o apuntar. Inventario se mantiene vacío. La rama `work/ao20-spells` incorpora el libro, Lanzar y diez accesos asignables, descritos en [SPELLS.md](SPELLS.md).

La consola recibe los eventos ya existentes de PlayerNetwork. Muestra entradas/salidas y diferencias confirmadas de vida/maná, además de muerte. No imprime cambios por movimiento ni presenta los valores iniciales del snapshot como daño. Separa Todo/Combate/Sistema, limita el historial a 200 mensajes y trata nombres como texto, sin ejecutar BBCode.

Los hechizos agregan eventos confirmados con nombre, lanzador, objetivo y efecto real; los rechazos se muestran sólo al solicitante. Los golpes físicos conservan el mensaje genérico de cambio de vida porque su protocolo todavía no informa atribución. `PlayerNetwork` conserva su tabla de RPC. El protocolo de hechizos usa otro autoload, `SpellNetwork`, y comprueba disponibilidad antes de habilitar Lanzar. Para probar magia hay que actualizar y reiniciar el servidor de `work/ao20-spells`.

## Prueba desde Windows

1. En GitHub Desktop: Fetch origin y elegir `work/ao20-spells` en Current branch.
2. Cerrar el servidor anterior y ejecutar `tools/Start-PrivateWebTest.cmd`. El lanzador importa los recursos y clases antes de abrir el servidor WSS. Para usar el editor, abrir el proyecto en Godot y esperar a que termine de importar.
3. Conectar dos clientes. Moverse con WASD, alternar Inventario/Hechizos y desplazarse por la consola. Comprobar que el movimiento sigue respondiendo después de esos clics.
4. Acercarse al otro jugador, orientarse hacia su casilla y pulsar CTRL. La pérdida de vida confirmada debe aparecer en ambas consolas; el golpe físico no gasta maná.
5. Probar filtros y desconexión desde Menú. Al reconectar se reinician el historial y las barras de la sesión anterior.

Los botones y atributos de AO20 para sistemas aún ausentes no producen estadísticas ni acciones ficticias. Esta iteración se limita a PvP; lobbies y bot quedan pendientes.

## Rediseño posterior

El marco y la disposición pertenecen a `CombatHUD`; las filas y accesos a `SpellSlotButton`. La selección y el apuntado están en `SpellTargetingController`, y las reglas autoritativas en el servidor. Cambiar texturas, colores y distribución no requiere rehacer los hechizos. Un rediseño que cambie el flujo de controles sí exige adaptar y volver a validar las interacciones y las coordenadas del área de juego.
