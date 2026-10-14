# Primera prueba Web de la Arena

Esta rama prepara la **arena Godot existente** para probarla en navegador. Conserva sus gráficos de AO, movimiento por casillas, colisiones, RPC y combate. El alcance vigente es PvP con un bot opcional cuando falte rival; PvE queda fuera por ahora. La siguiente iteración de gameplay se documenta en [PVP_GAMEPLAY.md](PVP_GAMEPLAY.md).

## Obtener los cambios

En GitHub Desktop, seleccioná el repositorio, pulsá **Fetch origin**, elegí `work/web-export-alpha` en **Current branch** y usá **Pull origin** cuando aparezca. Podés gestionar los commits, ramas, pull, push y stash desde esa aplicación.

Alternativa desde una terminal en la carpeta del repo:

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

## Probar la web privada HTTPS desde tu PC con WSS

El cliente alojado ya permite ingresar `wss://`; no hace falta exportarlo nuevamente para esta prueba. El servidor se inicia con TLS y escucha solamente en `127.0.0.1`. Ambas ventanas del navegador deben estar en la misma PC donde corre el servidor.

1. Detené el servidor anterior con Ctrl+C y actualizá la rama `work/web-export-alpha`. En GitHub Desktop: seleccioná esa rama en **Current branch**, pulsá **Fetch origin** y después **Pull origin** cuando aparezca. Si guardaste cambios en un stash para actualizar, conservá ese stash; sus cambios pueden requerir una resolución de conflictos con `network_manager.gd` al restaurarlos.
2. Instalá [mkcert](https://github.com/FiloSottile/mkcert), que crea certificados de desarrollo reconocidos por el navegador:

   ```powershell
   winget install --id FiloSottile.mkcert --exact
   ```

3. En GitHub Desktop, usá **Repository → Show in Explorer**. Entrá a la carpeta `tools` y abrí **`Start-PrivateWebTest.cmd` con doble clic**. Se abrirá un selector: elegí el ejecutable de Godot que usás para el proyecto. El lanzador abre su propia consola y mantiene visibles los errores si falla.

   También podés iniciarlo desde PowerShell si preferís indicar las rutas directamente:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Start-PrivateWebTest.ps1 -GodotExe "C:\ruta\Godot.exe"
   ```

   El parámetro `-GodotExe` debe apuntar al ejecutable real de tu editor. Si descargaste mkcert manualmente y no está en PATH, agregá `-MkcertExe "C:\ruta\mkcert.exe"`.

   Windows puede pedir permiso para confiar en la autoridad de desarrollo de mkcert. Los certificados y la clave se generan en `%LOCALAPPDATA%\ArgentumGodot\PrivateWebTest`, fuera del repo. El lanzador prepara la cadena completa y arranca el servidor real de Argentum. Si falta mkcert, el puerto está ocupado o el certificado falla, detiene el arranque.

4. Esperá los mensajes `PRIVATE LOCAL WSS: wss://127.0.0.1:7777 (loopback only).` y `Argentum server ready.`. Mantené esta terminal abierta.
5. Reiniciá el navegador si estaba abierto durante la instalación del certificado. Abrí el sitio privado, ingresá `wss://127.0.0.1:7777` en la pantalla de conexión y pulsá **Conectar**. Repetí en una segunda ventana y comprobá movimiento y sincronización.

En navegadores Chromium recientes, la página puede pedir permiso para acceder a la red local: permitilo para esta prueba. Si aparece un error de certificado, comprobá primero que `mkcert -install` terminó correctamente y reiniciá el navegador; no desactives la validación TLS.

Esta prueba mantiene el backend en tu PC: no crea un túnel ni abre puertos en el router. Para jugar desde otras computadoras habrá que preparar un servidor remoto con WSS y control de acceso.

Prueba adicional del servidor TLS (después de importar el proyecto):

```powershell
& "C:\ruta\Godot.exe" --headless --path . --script res://tests/server_tls_smoke.gd
```

Genera certificados temporales, comprueba el rechazo de configuraciones incompletas y verifica una conexión WebSocketMultiplayerPeer real por TLS en el puerto 17778. Elimina los certificados del test al terminar. No instala ninguna autoridad en Windows ni sustituye la prueba del navegador.

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

El usuario confirmó la exportación Web y dos clientes locales sincronizados en Godot 4.7.2 el 14/10/2026. La exportación entregada está alojada de forma privada para su propietario.

Se ejecutaron con Godot 4.7.2 el smoke test de conexión/cancelación (12 comprobaciones), el smoke test TLS (incluida una conexión WebSocketMultiplayerPeer real con validación del certificado) y el arranque del servidor dedicado. También se revisaron el preset, los filtros, el diff y la sintaxis del lanzador con PowerShell. Se corrigió el tipo explícito de `server_pid` en bootstrap porque el motor rechazaba su inferencia al importar la rama.

El lanzador completo se ejecutó con PowerShell 7 en Linux, mkcert y el servidor real: un cliente TLS verificó el certificado para `127.0.0.1` y recibió el upgrade WebSocket HTTP 101. La prueba incluyó rutas de certificados con espacios y una autoridad temporal sin instalarla en el sistema del entorno de preparación.

El acceso de doble clic conserva ese lanzador y agrega un selector del ejecutable de Godot mediante Windows Forms. Se comprobó la sintaxis PowerShell y se repitió la prueba completa con el ejecutable indicado por parámetro. El 14/10/2026 el usuario confirmó en Windows el arranque del servidor mediante el archivo CMD y la conexión correcta del cliente desde la web privada a través de WSS. Esta comprobación corresponde al backend local en su PC.

Pendiente antes de integrar en Alpha: confirmar F5/F2 en el editor. Las pruebas automatizadas del entorno de preparación se ejecutaron en Linux; la validación del navegador Windows fue reportada por el usuario. El backend sigue sin alojamiento remoto.

Referencias: [Exportar para Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [opciones de exportación Web](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html), [archivos no importados y filtros](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html).

TLS: [WebSocketMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_websocketmultiplayerpeer.html), [TLSOptions](https://docs.godotengine.org/en/stable/classes/class_tlsoptions.html), [mkcert](https://github.com/FiloSottile/mkcert) y [permiso de red local para WebSockets en Chromium](https://developer.chrome.com/release-notes/147).
