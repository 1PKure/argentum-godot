# Presentación pública de AO Mini

Guía para mantener el repositorio como entrada de portfolio y preparar la descarga y el video. El README presenta el juego; los detalles de implementación permanecen en la documentación técnica.

## Estado comprobado al preparar esta portada

- La rama predeterminada es `main`; el código del juego está en `Alpha`.
- La web comunicada en la documentación del proyecto es https://ao-mini.pulidomatias.workers.dev.
- No hay GitHub Releases ni un cliente Windows publicado.
- `export_presets.cfg` solo contiene el preset Web.
- El cliente release no inicia automáticamente un servidor local: `DevServerLauncher.should_auto_start_server()` habilita ese comportamiento únicamente en builds debug.
- El bot se simula en el servidor. La práctica también necesita un dedicado.
- No se ha identificado un video de presentación publicado con un enlace permanente.

Estos puntos describen la preparación editorial, no una comprobación de disponibilidad continua del servicio.

## Portada del repositorio

Mantener el mismo README público en `main` y `Alpha`. Los enlaces al código y a documentación técnica apuntan explícitamente a `Alpha`, porque esos archivos no existen en `main`.

Integrar el cambio de portada en `main` es lo que actualiza la vista que recibe alguien al abrir la URL del repositorio. Integrarlo solamente en `Alpha` no actualiza esa vista predeterminada.

La presentación usa AO Mini, el nombre de `project.godot` y de la web. Mantener ese nombre en el ZIP, los títulos del video y las capturas. Argentum Online explica la referencia del proyecto y sus créditos.

Descripción sugerida para About:

> Arena PvP inspirada en Argentum Online, desarrollada en Godot. Duelos 1v1, práctica contra bot y cliente web.

Website: https://ao-mini.pulidomatias.workers.dev

Topics sugeridos: `godot`, `gdscript`, `multiplayer`, `pvp`, `2d-game`, `argentum-online`.

## Distribución de Windows

### Experiencia recomendada para portfolio

Preparar un **ZIP portable con cliente y servidor local opcional**. Así una persona puede probar contra el bot sin depender de la VPS. Esto requiere empaquetado y validación: todavía no es una función ofrecida por la descarga.

El paquete debe permitir distinguir:

- **Jugar online:** conecta al servidor público mientras esté disponible.
- **Practicar localmente:** inicia un servidor local de la misma versión y conecta el cliente a él; no debe escribir en el ranking remoto.

No presentar el cliente online como una demo offline. El arranque local requiere un launcher que compruebe disponibilidad, gestione el proceso que inicia y cierre ese proceso al terminar. No usar una espera fija como única comprobación de que el dedicado está listo.

### Preparación de la versión

1. Elegir un commit probado de `Alpha` y registrar el SHA completo. El binario y el código fuente de la release deben corresponder a ese commit.
2. Instalar Godot Standard y los export templates de la misma versión que usa el proyecto; la documentación de builds actual usa 4.7.2.
3. Crear y validar un preset Windows Desktop x86_64, conservando los filtros de datos necesarios del preset Web y los avisos de recursos. Ese preset aún no existe.
4. Exportar cliente release. Si se ofrece práctica local, incluir el dedicado y el launcher probado, manteniendo la misma revisión de cliente/servidor.
5. Empaquetar el ejecutable, el PCK si no está embebido, los avisos/licencias correspondientes y un `LEEME.txt` corto. No incluir el editor, cachés, logs ni configuración administrativa del hosting.
6. Probar en una PC Windows sin Godot instalado: extracción en una ruta con espacios, inicio, sonido, controles, creación de sala, bot, resultado/revancha y cierre. Para online, comprobar compatibilidad con la versión del servidor público.
7. Si se anuncia práctica offline, repetir con internet desconectado y comprobar que no queden procesos del servidor iniciados por el launcher tras cerrar.
8. Crear una prerelease sobre ese commit, subir el ZIP y publicar un SHA-256 del archivo. Incluir versión, arquitectura, requisitos realmente comprobados, instrucciones y limitaciones.
9. Comprobar la descarga desde una sesión sin autenticar y abrir el ZIP descargado.
10. Actualizar el README solo cuando el archivo sea público y utilizable.

Nombre sugerido: `AO-Mini-<version>-Windows-x64.zip`.

El botón debe apuntar al archivo publicado o a la release concreta. Mantener también el enlace general a Releases para consultar versiones anteriores. No usar `/releases/latest` para una alpha publicada únicamente como prerelease: el enlace debe identificar una versión que realmente esté disponible.

### Texto de la descarga

Antes de publicar, conservar el estado honesto del README: descarga pendiente.

Después de validar la release, reemplazarlo por:

> **Descargar para Windows x64** · Versión [versión real]. Descomprimí el ZIP y seguí las instrucciones incluidas.

Indicar explícitamente si esa versión requiere servidor online o incluye práctica con servidor local. No prometer juego offline si esa ruta no se ha comprobado.

## Video de presentación

Propuesta: **45–60 segundos, 1920×1080 y gameplay real**. Usar una resolución y una tasa de cuadros que el equipo pueda grabar de forma estable.

| Tiempo aproximado | Contenido | Mensaje |
| --- | --- | --- |
| 0–5 s | La mejor secuencia breve de un duelo, seguida del título | AO Mini · Arena PvP |
| 5–12 s | Elegir una clase y mostrar brevemente la preparación | Elegí tu estilo de combate |
| 12–32 s | Combate legible: movimiento, hechizos y recuperación | Duelos 1 contra 1 |
| 32–42 s | Práctica contra bot y cambio de arena | Entrená y probá distintas clases |
| 42–52 s | Resultado y revancha | Una ronda más |
| 52–60 s | Cierre con autor y URL del repositorio | Matias Pulido · Desarrollado en Godot |

Mostrar solo sistemas que funcionen en la versión grabada. Evitar tiempos de carga, configuración del servidor y texto técnico largo. Conservar el sonido del combate; cualquier música añadida debe poder usarse en la publicación.

Preparar también tres capturas reales: combate, selección de clase/sala y una segunda arena. Ocultar datos personales del chat y usar nombres de prueba para la grabación.

### Publicación e integración

- Publicar el video en un enlace permanente, por ejemplo YouTube, y comprobar acceso sin iniciar sesión.
- Añadir una miniatura real al README que abra ese video. Un enlace con miniatura evita depender de la reproducción embebida en Markdown.
- Guardar las capturas optimizadas en `docs/media/` cuando estén elegidas. No se crean imágenes de gameplay ficticias ni enlaces vacíos.
- Subir el video de forma nativa en LinkedIn y acompañarlo con el enlace al repositorio para ver el proyecto y descargar la demo publicada.

Plantilla Markdown para reemplazar con rutas y URL reales, una vez disponibles:

```markdown
[![Ver gameplay de AO Mini](docs/media/gameplay-preview.jpg)](URL_REAL_DEL_VIDEO)
```

## Antes de compartir el repositorio en LinkedIn

- README integrado en la rama predeterminada y coherente con `Alpha`.
- Video y capturas muestran el estado real del juego.
- Descarga Windows publicada, descargada y probada en una PC sin editor.
- Estado online explicado sin prometer disponibilidad permanente.
- Créditos y avisos de recursos conservados en el repositorio y el paquete.
- Enlaces públicos comprobados sin autenticación.

La portada y esta guía preparan la presentación. No publican un binario, no crean el video y no cambian la disponibilidad del servidor.
