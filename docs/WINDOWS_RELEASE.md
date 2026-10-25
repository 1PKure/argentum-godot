# Windows: construir y publicar

## Paquete portable

El preset `Windows Desktop` exporta una demo x64 con la característica `local_demo`. Al abrir `AO-Mini.exe`, `LocalDemoSession` inicia el mismo ejecutable en modo dedicado, en un puerto libre de loopback, y espera una señal de disponibilidad antes de mostrar el cliente.

Conectar a la dirección precargada, crear una sala y añadir un bot. El paquete no necesita Godot instalado, internet ni acceso a la VPS. El ranking de práctica se guarda en `user://local_demo/ranking.json`; la demo omite la inicialización de almacenamiento remoto, aunque el proceso herede configuración de hosting.

Cerrar el cliente termina su dedicado. Si el cliente falla abruptamente, el dedicado se detiene al perder la señal de actividad durante diez segundos. La búsqueda de puerto no reutiliza servidores de otras instancias; si otro proceso ocupa el puerto durante el arranque, la demo informa el fallo.

El preset Web y el arranque de desarrollo mantienen su funcionamiento. `--no-auto-server` permite omitir el arranque local para pruebas con un dedicado existente.

## Construcción

Requisitos de desarrollo: Godot 4.7.2 Standard, export templates de la misma versión, Python 3.11+ y Git. Los jugadores solo necesitan el ZIP.

Desde un commit limpio:

```bash
python tools/package_windows.py --godot RUTA_AL_EJECUTABLE_GODOT --version 0.1.0-alpha.1
```

La herramienta importa, exporta, recoge licencias y registra el commit, versión del motor y hashes de archivos en `release.json`. Genera un ZIP y un archivo `.sha256` en `builds/releases/`. No sobrescribe paquetes anteriores. Los logs quedan en `builds/logs/`.

## Validación

```bash
GODOT --headless --path . --script tests/local_demo_smoke.gd
python tests/run_local_demo.py --godot RUTA_GODOT
```

Estas pruebas cubren arranque real, conexión WebSocket, configuración de almacenamiento heredada, cierre normal, partidas en dos salas, práctica con bot y cierre tras caída del cliente.

Antes de publicar, probar el ZIP descargado en Windows sin editor instalado, extraído en una ruta con espacios:

1. Desconectar internet y abrir `AO-Mini.exe` sin permisos de administrador.
2. Conectar con apodo, crear sala, elegir clase/arena y añadir bot.
3. Jugar una ronda; comprobar sonido, FPS, controles, pausa, resultado y revancha.
4. Cerrar y comprobar que termina el dedicado. Abrir nuevamente y verificar preferencias/progreso.
5. Abrir dos instancias y comprobar que cada una utiliza su propio puerto.

Las pruebas headless en Linux y una exportación correcta no sustituyen esta comprobación visual y de audio en Windows.

## Publicar

1. Una vez validada, integrar la preparación en `Alpha` y promocionar la versión a `main`, conservando el README público.
2. Construir desde el commit exacto que se etiquetará. Si el merge crea otro commit, volver a construir desde ese commit: el `source_sha` del paquete debe coincidir con el tag.
3. Crear el tag `v0.1.0-alpha.1` sobre ese commit y una **prerelease** en GitHub Releases.
4. Adjuntar el ZIP y su `.sha256`; el código fuente queda identificado por el tag.
5. Incluir instrucciones breves: descomprimir, abrir el EXE, conectar y crear una sala con bot. Indicar Windows x64 y práctica local.
6. Comprobar la descarga sin autenticación y añadir al README el enlace de esa prerelease concreta.

El ejecutable de esta primera demo no lleva firma digital. No presentar la build como probada en Windows hasta completar el control manual.

## Ajustes de la demo 0.1.0-alpha.2

- Rayo Elemental: 800 de maná (antes600) y daño final reducido12%; Apocalipsis conserva sus valores.
- Bot semimágico: con al menos35% de vida, retoma la aproximación si el rival queda a tres casillas o más, o tras1.6segundos de recuperación. Conserva la retirada de emergencia y los intervalos de combate/pociones.
- Sangre: mismas diez gotas,15% más largas y20% más anchas; duración0.50s (antes0.38s).
- Meditación: escala10% mayor en ambos modos, conservando el anclaje a los pies.

La build incluye cliente y servidor de la misma revisión. Estos ajustes requieren una actualización de cliente y dedicado para trasladarse al juego online.


## Primera prerelease publicada

[`v0.1.0-alpha.3`](https://github.com/1PKure/argentum-godot/releases/tag/v0.1.0-alpha.3) identifica el commit `3b2cd8674cbdbce221337dff6ab7f5c02aca76b9`. Incluye el ZIP portable de Windows x64 y su `.sha256`. Los archivos de código fuente los genera GitHub; no son la descarga jugable.

Esta versión conserva los ajustes aprobados de balance, bot y efectos, y restaura la detención visual al paralizarse o morir. El enlace de descarga usa el tag concreto porque GitHub no incluye las prereleases en `releases/latest`.
