# Identidad visual de la arena

Primera pasada propia de presentación, sin cambiar el balance aprobado.

## Interfaz

HUD original de Godot: paneles azul noche, texto marfil, bordes suaves y acentos dorados; barras de recursos propias, encabezado compacto, consola arriba, minimapa ampliado, vida arriba y maná debajo, sobre las opciones inferiores, libro/inventario y accesos separados. Se retira el marco AO20 de la presentación activa; sus archivos y atribuciones se conservan porque otros recursos del prototipo siguen procediendo de AO20.

Todas las ventanas usan `arena_presentation_theme.gd`: conexión, menú, controles/atajos, clases/presets, bot, skins y escenarios. El selector de clases incluye el mismo tratamiento de panel, tipografía, desplegable y acciones. Las opciones de combate conservan el foco de teclado para movimiento/macros; escribir en el buscador conserva su comportamiento.

Pociones y símbolos de hechizos originales en SVG, cargados por `ArenaIcons`. Rojo y azul siguen identificando vida y maná. Cada uno de los 39 hechizos tiene su propia silueta/icono, para no repetir símbolos abstractos por familia. Un mismo hechizo asignado a dos slots conserva su mismo icono; clic derecho vacía un slot. El equipo y los personajes conservan los recursos AO20 ya elegidos; esto no es un reemplazo completo de sus animaciones ni una versión final de dirección artística.

## Escenarios

Se conservan exactamente los pisos interiores y el catálogo de colisiones. Los nuevos props usan SVG con volumen, detalles y sombras. El bosque y los demás props se dibujan por debajo de los personajes: no ocultan el cuerpo cuando ocupás una casilla vecina. No se modifica la casilla bloqueada.

Lava exterior usa roca oscura con grietas finas de escala fija del mundo y brillo lento. No desplaza las placas, no crea flashes ni añade daño. El problema anterior era escalar un patrón UV sobre todo el padding exterior.

## Magia y meditación

`ArenaSpellVisual` dibuja y anima los39 conceptos con código nuevo; ninguna animación/hoja AO20 se muestra como capa principal. La referencia conserva el concepto: Descarga tiene dos esferas eléctricas que convergen, Tormenta abre fuego/partículas y Apocalipsis una gran explosión con silueta de cráneo. Los demás efectos tienen variantes propias de curación, control, raíces, implosión y protección. La meditación compacta azul/dorada aprobada se conserva.

Al abrir Hechizos, la columna da prioridad al libro y su botón Lanzar; al volver a Inventario restaura el minimapa ampliado. Se retira el catálogo completo de la UI y se muestran únicamente las opciones de combate legales de la clase, en orden útil. Los datos DAT/reglas importados permanecen para referencia; no se cambian costes ni daños. Los macros guardados conservan huecos y asignaciones válidas; los básicos retirados vuelven al valor de combate del preset.

Se conservan anclaje a pies, seguimiento interpolado, palabras del lanzador y separación de barras/nombre. El servidor aplica las mismas reglas, costes, daños y recargas. El efecto visual no aplica ni retrasa daño. Flecha y sangre aprobadas permanecen. El golpe usa el audio Firefly aportado por Mati, con recorte de silencio/cola y atenuación; las colas de audio pueden terminar después de apagar los gráficos.

## Validación

Import y render nativo GL Compatibility. Los smoke de interfaz verifican recursos propios, foco, filtros, consola y reconexión; las pruebas con PCK y dedicado comprueban inventario/macros/pociones y cambio sincronizado de escenario. HUD y ventanas se revisan en cuatro resoluciones. `combat_feedback_smoke.gd` comprueba las nuevas familias, anclaje, seguimiento, limpieza y flecha/sangre. Hay galería renderizada de todos los hechizos para QA.

La revisión estética y de sonido en navegador Windows sigue siendo manual. Próximas iteraciones pueden mejorar animaciones de personajes/equipo y detalles artísticos sin volver a alterar el combate.
