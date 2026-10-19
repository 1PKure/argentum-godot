# Interfaz de combate de la arena

HUD propio de Godot en azul noche, marfil y dorado. La consola vuelve encima de la arena; el minimapa aumenta a168×100 y los recursos quedan abajo de la columna lateral. La barra de vida está justo encima de Menú/Desconectar; maná va encima de vida. Base1280×800, escala uniforme y área de juego adaptable a ventanas más anchas.

## Inventario, libro y accesos

Se ven seis filas en la resolución de diseño, conservando los42 espacios autoritativos mediante desplazamiento. Ningún objeto se pierde por ampliar el minimapa. MarcaE y tooltip identifican equipo; clic izquierdo equipa/desequipa o selecciona/bebe; mantener botón derecho y arrastrar reorganiza. Cancelar, abrir modales, perder foco, cambiar inventario o desconectar cancela el movimiento pendiente.

Inventario y libro son pestañas independientes de los macros. El libro permite buscar y consultar el catálogo completo. Arrastrar un hechizo a un acceso lo asigna; clic derecho sobre un macro elimina esa asignación para la clase. Las teclas personalizadas aparecen en slots y tooltips. [Controles](CONTROLS.md).

Se conservan los iconos de pociones aprobados y hay39 símbolos individuales de hechizos; compartir una familia ya no obliga a repetir el icono. Un mismo hechizo asignado más de una vez conserva el mismo icono. No se eliminan automáticamente esas asignaciones del jugador.

## Magia y sonido

Los FX retienen sus siluetas/animaciones AO20 disponibles, con luz/partículas suaves. Apocalipsis conserva su explosión grande y Descarga su nube/rayos. Se anclan a los pies por su último píxel visible y siguen al objetivo interpolado; las palabras siguen al lanzador. El nombre y las barras del avatar quedan debajo para liberar las palabras. Meditación, pociones durante meditación, flecha y sangre mantienen comportamiento aprobado.

Un golpe cuerpo a cuerpo confirmado reproduce `custom/audio/melee_hit.wav`, contacto corto generado para el proyecto. Rechazos/misses no producen impacto. Su intervalo autoritativo es1200ms, igual que la flecha. Pausar el bot también congela audio/animaciones del mundo.

## Menú, pausa y conexión

Menú → Controles y atajos permite reasignar teclado y restaurar predeterminados. Abrir opciones pausa sólo la práctica individual con bot mediante el reloj del servidor; cerrar reanuda. En PvP humano el duelo sigue. Menú → Salir de la sala vuelve al directorio sin cortar conexión; Desconectar en el pie cierra la conexión y muestra nuevamente su pantalla.

Conexión, menú, controles, clases/presets, bot, skins, escenarios y lobbies usan el mismo tema. Los botones y scrollbars preservan foco de combate; el buscador captura texto hastaEnter. M/Q/E/Espacio/1–0 permanecen como predeterminados reasignables y no hay botones permanentes Meditar/Vida/Maná/Usar.

La consola conserva filtros y máximo200 mensajes. Sólo muestra eventos que competen al jugador y no revela maná/costes privados del rival. Autoría y daño de golpes provienen del evento confirmado del servidor. Los nombres se tratan como texto literal.

## Prueba

GitHub Desktop → work/arena-lobbies → Pull. Reiniciar `tools/Start-PrivateWebTest.cmd`, Ctrl+F5 en la misma web privada y conectar al WSS precargado. Protocolo18 en ambos lados. Crear/unirse → clase/preset → Listo → duelo; el bot es opcional si falta otro humano.

`run_lobby_native.py` prueba el PCK exportado con dos humanos y luego un bot: navegación, movimientos, apuntado, pociones, rebind real deUsar, clic derecho en macro, scroll hasta último objeto, cuatro resoluciones, pausa/reanudación y desconexión. La revisión estética y auditiva en navegador Windows sigue siendo manual.
