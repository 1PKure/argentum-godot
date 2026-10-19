# Salas PvP 1v1

El cliente ahora conecta al directorio de salas antes de entrar a una arena. No necesita cuentas, base de datos ni servicios pagos.

1. Crear una sala con nombre y escenario, o unirse a una sala existente.
2. Elegir clase. **Ver preset** y **Skins** abren las ventanas comunes por encima de la sala. El anfitrión puede cambiar el escenario antes del duelo.
3. Con dos jugadores, ambos deben marcar **Listo**. A solas se puede añadir un bot y luego marcar **Listo**.
4. Cuenta autoritativa de tres segundos; combate bloqueado en el servidor hasta terminar.
5. Al morir un rival aparece el resultado. Ambos pueden marcar **Listo** para una revancha, cambiar clase/mapa o salir.

El bot conserva su balance y sus recompensas existentes. El bot sólo está disponible con un humano; una segunda persona puede entrar mientras la sala está esperando, y reemplaza esa opción. Las rondas en curso no admiten incorporaciones.

## Autoridad y aislamiento

Cada sala tiene su propio `PlayerRegistry`, `ArenaPracticeBot` y `ArenaSession`. Movimiento, ataques, proyectiles, hechizos, recuperación, inventario, skins, snapshots y efectos se resuelven dentro de ese registro. Al cambiar de sala se descartan revisión de mapa, avatares/efectos, selección de hechizo, solicitudes pendientes y poción mantenida antes de recibir el nuevo snapshot. La cuenta cierra ventanas previas y libera el foco de texto. Los eventos se envían sólo a los miembros de la sala; el maná rival sigue siendo privado.

Hay dos plazas por sala, hasta 32 salas y 64 conexiones. El servidor rechaza salas llenas, identificadores inexistentes, comandos repetidos, configuraciones inválidas y cambios de clase/arena durante una ronda. Cambiar clase/mapa/bot o entrar un rival borra todos los estados Listo. Los comandos de sala tienen un mínimo de 150 ms entre solicitudes por conexión.

Salir o desconectarse interrumpe la ronda sin otorgar victoria; el anfitrión pasa al miembro restante. La sala se elimina cuando queda vacía. No hay persistencia del listado ni reconexión automática a una ronda anterior. El nombre es de sala, no una identidad/cuenta de jugador.

Protocolo de red **17**: actualizar cliente y dedicado juntos. El lanzador `.cmd` conserva el puerto 7777. Para pruebas simultáneas aisladas se puede ejecutar el dedicado con `-- --server --port=17877`.

## Verificación

- `tests/lobby_isolation_smoke.gd`: reglas y dos salas simultáneas; capacidad, estados, bloqueo, bot aislado, daño, muerte, revancha, anfitrión, cambio de arena/clase y limpieza.
- `python tests/run_lobby_network.py --godot /ruta/al/ejecutable`: inicia dedicado 17877, cuatro clientes y luego solo+bot; conserva logs, usa marcadores nuevos y cierra todos los procesos al finalizar.
- `tests/lobby_ui_smoke.gd`: paneles/listado/resultado y controles en 1280×800,1280×720,1920×1080 y800×600; captura nativa de las dos vistas.
- `tests/lobby_network_client.gd`: cuatro procesos cliente contra dedicado 17877, dos salas, mapas diferentes, Listo/cuenta/combate, snapshots/stats/movimiento/FX privados por sala y daño sin contaminación entre salas. Usar roles A/B/C/D y un directorio de marcadores nuevo con `--lobby-role=A --lobby-markers=/ruta/temporal`.
- Los tests antiguos de red que esperaban aparecer inmediatamente en una arena compartida requieren adaptar su preparación a Crear/Unirse/Listo; los tests de reglas no dependen de ese flujo.

Pendiente de revisión humana: navegador Windows con dos pestañas/dispositivos, latencia real y valoración visual. No se modifica el hosting ni su audiencia.

`tests/run_lobby_native.py` usa un PCK exportado y dos clientes renderizados para probar clics de Crear/Unirse/Listo, preset/skins, cierre de modales al empezar, WASD, macro+objetivo, pociones con apuntado y salida/reentrada. Requiere `--godot`, `--pck` y Xvfb en Linux (`--xvfb`/`--library-path` opcionales). La ejecución local final pasó 34 comprobaciones.
