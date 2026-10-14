# Primera prueba Web de la Arena

Esta rama prepara la **arena Godot existente** para probarla en navegador. Conserva sus gráficos de AO, movimiento por casillas, colisiones, RPC y combate. Los lobbies, bots y PvE se implementarán después.

## Obtener los cambios

Desde la carpeta del repo:

```bash
git fetch origin
git switch --track origin/work/web-export-alpha
```

Si ya tenés esta rama local, usá `git switch work/web-export-alpha` y `git pull --ff-only`.

Abrí `project.godot` en la misma versión de Godot que usás para Alpha. La configuración declara 4.7; instalá las plantillas de exportación que coincidan exactamente con tu editor desde **Editor → Manage Export Templates**.

## 1. Comprobar el editor

Ejecutá el proyecto con F5. El editor debe seguir iniciando el servidor de desarrollo y conectando automáticamente. F2 debe abrir el segundo cliente, como antes. Comprobá movimiento, colisiones, ataque con Ctrl y muerte como fantasma. Después detené la ejecución.

## 2. Iniciar el servidor dedicado

El navegador no abre procesos Godot. Iniciá el servidor en otra terminal, desde la carpeta del proyecto:

```bash
godot --headless --path . -- --server
```

Si `godot` no está en PATH, reemplazalo por la ruta de tu ejecutable. En PowerShell, una ruta entre comillas necesita `&` delante. Dejá esta terminal abierta durante la prueba. Debe informar que el servidor WebSocket está listo en el puerto 7777.

## 3. Exportar el cliente Web

1. Creá la carpeta `builds/web`.
2. Abrí **Project → Export** y seleccioná el preset **Web** incluido.
3. Exportá como `builds/web/index.html`. Para la primera prueba podés usar una exportación debug.
4. Probá mediante el botón de ejecución Web del editor, que sirve el proyecto por HTTP local. No abras el HTML con doble clic (`file://`).
5. En la pantalla de conexión, dejá `ws://127.0.0.1:7777` y pulsá **Conectar**.
6. Abrí otro cliente del mismo build en una segunda ventana del navegador. Ambas ventanas deben conectarse al mismo servidor y ver a los dos jugadores.

Al escribir en la pantalla de conexión, WASD no debe mover al personaje. Probá **Cancelar** durante un intento y luego conectá con la dirección correcta. Si el servidor se cae, debe volver a aparecer la pantalla de conexión y el movimiento debe quedar deshabilitado.

Si no hay servidor, se muestran los intentos y luego un error recuperable. Para probar esto sin esperar todos los intentos, usá Cancelar.

### Qué incluye el preset

- Compatibility, ya configurado en el proyecto.
- Exportación sin threads ni GDExtensions; no requiere configurar aislamiento entre orígenes para esta prueba.
- Todas las texturas importadas y filtros explícitos para `assets/argentum/source/data/*.ini` y `*.dat`.
- Exclusión de builds, documentación, tests y archivos temporales.
- PWA desactivada para evitar que una caché de otra versión confunda las pruebas iniciales.

## Dirección del servidor

La dirección por defecto se configura en **Project Settings → Network → Server Url**, con Advanced Settings activado, o en la sección `[network]` de `project.godot`:

```ini
[network]
server_url="ws://127.0.0.1:7777"
```

El cliente Web permite cambiarla en la pantalla de conexión sin volver a exportar. El valor ingresado se utiliza solo para esa sesión y no se guarda en el proyecto.

Para una web alojada con HTTPS usaremos un endpoint `wss://` accesible para sus visitantes. El servidor Godot se ejecuta por separado; alojar estos archivos no inicia el servidor. `127.0.0.1` siempre se refiere a la computadora de quien juega.

## Prueba automática en Godot

Después de que el editor haya importado el proyecto, podés ejecutar:

```bash
godot --headless --path . --script res://tests/web_connection_smoke.gd
```

El script prueba configuración, entrada inválida, señales del panel, bloqueo de envíos duplicados, conexión WebSocket real en loopback y cancelación/reinicio sin que los temporizadores anteriores afecten la sesión nueva. Necesita el puerto TCP 17777 libre y termina con código 0 si pasa.

Esta prueba no reemplaza la verificación de la exportación en el navegador ni comprueba el servidor remoto con TLS.

## Entregar la exportación para alojamiento privado

Una vez que funcionen ambos clientes, comprimí **todo el contenido de `builds/web`** en un ZIP. Incluí el HTML, JS, WASM, PCK, imágenes e íconos generados; conservá sus nombres. Ese ZIP permitirá alojar el cliente real. La carpeta de builds está excluida de Git.

El preset incluye `noindex`, pero esto no es un control de acceso. El alojamiento debe mantenerse privado para el propietario.

## Estado de validación de esta preparación

Se revisan sintaxis GDScript con un parser externo, el preset, referencias y el alcance del diff. La ejecución del smoke test, el editor y la exportación Web requieren Godot: deben completarse en tu PC antes de integrar la rama en Alpha.

Referencias: [Exportar para Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [opciones de exportación Web](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html), [archivos no importados y filtros](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html).
