# AO Mini

### Arena PvP inspirada en Argentum Online, desarrollada en Godot

Un proyecto personal de **Matias Pulido (1PKure)** que lleva el combate de Argentum Online a una arena de duelos: elegir una clase, preparar los controles y enfrentarse a otro jugador o practicar contra un bot.

El foco está en la habilidad del jugador: movimiento, puntería, combinación de hechizos y administración de vida y maná.

**[Visitar la web](https://ao-mini.pulidomatias.workers.dev)** · **[Versiones y descargas](https://github.com/1PKure/argentum-godot/releases)** · **[Explorar el código](https://github.com/1PKure/argentum-godot/tree/Alpha)**

> **En desarrollo.** La disponibilidad del juego online depende de las sesiones de prueba y del servidor. Todavía no hay una versión descargable de Windows publicada en Releases.

## La experiencia

- **Duelos 1 contra 1:** salas independientes, preparación, cuenta regresiva, resultados y revancha.
- **Práctica contra bot:** entrenamiento con distintas clases y controles de pausa y reinicio.
- **Nueve clases:** presets de equipo y estilos de combate con magia, cuerpo a cuerpo y arco.
- **Cuatro arenas:** Bosque, Desierto, Lava y Sala de Duelos.
- **Controles configurables:** juego clásico con selección de hechizos o accesos rápidos mediante macros.
- **Personalización y comunidad:** skins por clase, chat de sala y ranking.

## Jugar y descargar

### Navegador

La [web del proyecto](https://ao-mini.pulidomatias.workers.dev) es el punto de entrada para las pruebas online. La página puede seguir disponible aunque el servidor de partidas esté fuera de servicio.

### Windows

La distribución del cliente se centralizará en [GitHub Releases](https://github.com/1PKure/argentum-godot/releases), con un ZIP, instrucciones y la versión correspondiente. La descarga aún está pendiente de publicación.

**El cliente de Windows también necesita un servidor compatible**, incluso para practicar contra el bot. Una descarga del cliente por sí sola no habilita el juego sin conexión. Para mantener una demo jugable cuando el servidor público esté apagado, la distribución deberá incluir y validar un servidor local.

## Desarrollo

Construido con **Godot 4.7 Standard y GDScript**, con cliente nativo y web, y un servidor dedicado autoritativo conectado por WebSocket/WSS. El servidor valida las acciones de combate y mantiene aisladas las partidas de cada sala.

El trabajo incluye sistemas de combate, comportamiento del bot, interfaz, efectos visuales, sincronización multijugador y herramientas de prueba.

El código del juego está en la rama [`Alpha`](https://github.com/1PKure/argentum-godot/tree/Alpha). La documentación técnica permite profundizar en [salas](https://github.com/1PKure/argentum-godot/blob/Alpha/docs/LOBBIES.md), [clases](https://github.com/1PKure/argentum-godot/blob/Alpha/docs/CLASSES.md) y [controles](https://github.com/1PKure/argentum-godot/blob/Alpha/docs/CONTROLS.md).

<!-- Presentación visual: insertar aquí una captura real enlazada al video de gameplay cuando ambos estén publicados. Guía editorial: docs/PUBLIC_PRESENTATION.md. No usar enlaces de ejemplo ni imágenes que simulen gameplay. -->

## Autor y créditos

**Matias Pulido · [1PKure](https://github.com/1PKure)** — desarrollo del proyecto.

AO Mini es un proyecto independiente inspirado en Argentum Online. Utiliza recursos de Argentum Online / AO20, con créditos a **Noland Studios** y a sus autores originales. La procedencia y los avisos de los recursos se conservan en el repositorio, incluida la [documentación de recursos AO20](https://github.com/1PKure/argentum-godot/blob/Alpha/assets/argentum/interface/ao20/README.md).

El código se publica bajo [GNU AGPL-3.0](LICENSE). Los recursos de terceros conservan sus propias licencias; la licencia del código no reemplaza sus condiciones.
