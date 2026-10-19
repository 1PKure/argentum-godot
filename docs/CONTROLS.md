# Controles de la arena

Menú → Controles y atajos: pulsar la acción, luego la tecla o combinación. Esc cancela una captura sin borrar el atajo anterior. Se rechazan conflictos, incluido un Ctrl aislado y una combinación con Ctrl. Restaurar devuelve todos los controles de teclado; no borra las asignaciones de hechizos por clase.

Predeterminados: WASD movimiento; Ctrl golpe/arco; L Lanzar seleccionado; M meditar; Q/E pociones; Espacio usar poción seleccionada (mantener repite); 1–0 macros; Esc cancelar apuntado y, sin apuntado, abrir/cerrar Menú. Clic izquierdo usa/equipa objetos; derecho arrastra inventario. Arrastrar un hechizo desde el libro lo asigna a un macro; clic derecho en ese macro lo vacía. Una ranura vacía persiste al cambiar clase, preset, sala o reiniciar.

Atajos y macros se guardan por perfil local estable, no por ID de conexión. Sin cuentas, la persistencia es por dispositivo/navegador; borrar datos locales elimina preferencias. Las etiquetas de macros y tooltips siguen las teclas configuradas. La captura y los modales bloquean gameplay, liberan teclas/pociones sostenidas y no capturan la tecla que abre la ventana.

## Pausa

Abrir Menú o una ventana de opciones durante práctica individual contra bot solicita pausa al servidor. La simulación de esa sala congela movimiento, IA, regeneración, estados, cuenta y recargas con un reloj lógico. El cliente pausa sus animaciones y audio de mundo; red y UI permanecen activas. Cambiar Menú → Controles conserva la pausa. Cerrar, salir o desconectar no deja otra sala pausada. En PvP humano el menú sólo bloquea la entrada local; el duelo sigue.

El botón Desconectar inferior cierra la conexión; Menú → Salir de la sala vuelve al directorio conservándola. Cliente/servidor requieren protocolo18.

## Validación

`controls_bindings_smoke.gd`: conflictos, combinaciones, persistencia, vacíos por clase, captura y tamaños. `bot_pause_smoke.gd`: relojes/estados/recargas y aislamiento. `run_lobby_native.py`: PCK exportado, dos humanos y luego bot, clics reales en controles, atajo Usar, macros, pausa/reanudación y desconexión. `melee_feedback_smoke.gd`: audio sólo al impacto confirmado y limpieza/pausa.
