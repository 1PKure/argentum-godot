# Controles de la arena

Menú → Controles y atajos: pulsar la acción, luego la tecla o combinación. Esc cancela una captura sin borrar el atajo anterior. Se rechazan conflictos, incluido un Ctrl aislado y una combinación con Ctrl. Restaurar devuelve todos los controles de teclado; no borra las asignaciones de hechizos por clase.

Predeterminados: WASD movimiento; Ctrl golpe/arco; L Lanzar seleccionado; M meditar; Q/E pociones; Espacio usar poción seleccionada (mantener repite); 1–0 macros; Esc cancelar apuntado y, sin apuntado, abrir/cerrar Menú. Clic izquierdo usa/equipa objetos; derecho arrastra inventario. Arrastrar un hechizo desde el libro lo asigna a un macro; clic derecho en ese macro lo vacía. Una ranura vacía persiste al cambiar clase, preset, sala o reiniciar.

Atajos y macros se guardan por perfil local estable, no por ID de conexión. Sin cuentas, la persistencia es por dispositivo/navegador; borrar datos locales elimina preferencias. Las etiquetas de macros y tooltips siguen las teclas configuradas. La captura y los modales bloquean gameplay, liberan teclas/pociones sostenidas y no capturan la tecla que abre la ventana.

## Pausa

Abrir Menú o una ventana de opciones durante práctica individual contra bot solicita pausa al servidor. La simulación de esa sala congela movimiento, IA, regeneración, estados, cuenta y recargas con un reloj lógico. El cliente pausa sus animaciones y audio de mundo; red y UI permanecen activas. Cambiar Menú → Controles conserva la pausa. Cerrar, salir o desconectar no deja otra sala pausada. En PvP humano el menú sólo bloquea la entrada local; el duelo sigue.

El botón Desconectar inferior cierra la conexión; Menú → Salir de la sala vuelve al directorio conservándola. Cliente/servidor requieren protocolo21.

## Validación

`controls_bindings_smoke.gd`: conflictos, combinaciones, persistencia, vacíos por clase, captura y tamaños. `bot_pause_smoke.gd`: relojes/estados/recargas y aislamiento. `run_lobby_native.py`: PCK exportado, dos humanos y luego bot, clics reales en controles, atajo Usar, macros, pausa/reanudación y desconexión. `melee_feedback_smoke.gd`: audio sólo al impacto confirmado y limpieza/pausa.

## Libro de combate

La pestaña Hechizos usa más altura para mostrar unas seis entradas y Lanzar; Inventario restaura el minimapa ampliado. Se filtran Dardo/Flecha/Misil básicos, curaciones iniciales y variantes redundantes. Los datos/reglas originales permanecen en el proyecto; la selección y los macros de la arena usan el catálogo de combate. Asesino/Paladín/Bandido priorizan golpe físico enmacro3, Druida Rayo Elemental y las clases con Descarga la conservan. Los huecos guardados no se rellenan automáticamente. Vida siempre arriba de maná.

Al pulsar una dirección bloqueada por rival, pared o raíz, el jugador puede orientarse sin cambiar de tile. El giro comparte la cadencia de movimiento y no interrumpe meditación estando quieto. No evita los bloqueos de ronda o pausa.

Libro: mantené botón derecho y arrastrá un hechizo sobre otro para ordenar la lista. Se guarda localmente por perfil y clase; no modifica macros. Clic izquierdo conserva selección/Lanzar y arrastre hacia macros. Escape o soltar afuera cancela el movimiento.

Movimiento:140ms por tile para jugador y bot (antes120), aproximadamente14% menos velocidad. Entre teclas de movimiento mantenidas gana la última presionada; soltarla retoma la anterior. Cambiar dirección conserva la recarga de paso para evitar movimientos extra. Las colisiones y el giro junto a un rival se mantienen.

Meditación: primer pulso500ms,5% del máximo cada500ms; recibir daño no letal no la interrumpe. Pociones compatibles. Morir, moverse, atacar/lanzar, cancelar o llenar maná sí la finalizan. Bot132ms/tile, jugador140ms/tile.
