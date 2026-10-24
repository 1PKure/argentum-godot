# AO Mini

Arena PvP inspirada en Argentum Online, centrada en duelos rápidos y combate basado en habilidad.

**[Web](https://ao-mini.pulidomatias.workers.dev) · [Releases](https://github.com/1PKure/argentum-godot/releases)**

## El juego

- Duelos 1 contra 1 con salas, resultados y revancha.
- Práctica contra bot con pausa y reinicio.
- Nueve clases con magia, combate cuerpo a cuerpo y arco.
- Cuatro arenas, skins, chat y ranking.
- Controles configurables y modos clásico o con macros.

## Ejecutar el proyecto

1. Clonar la rama `Alpha` y abrir `project.godot` con **Godot 4.7.2 Standard**.
2. Ejecutar con **F5**; el entorno de desarrollo inicia el servidor local.
3. Conectar, crear una sala, elegir clase y agregar un bot o un segundo jugador.

El servidor valida el combate y mantiene aisladas las salas. La versión Web necesita un dedicado; la exportación Windows incluye el arranque de un servidor local para practicar sin internet.

## Exportar para Windows

Con Python 3.11+, Git y los export templates de Godot 4.7.2 instalados:

```bash
python tools/package_windows.py --godot RUTA_AL_EJECUTABLE_GODOT --version 0.1.0-alpha.1
```

El empaquetado requiere un checkout limpio y genera el ZIP, las licencias, el manifiesto de versión y su SHA-256 en `builds/releases/`.

[Publicar una release](docs/WINDOWS_RELEASE.md) · [Controles](docs/CONTROLS.md) · [Clases](docs/CLASSES.md) · [Salas](docs/LOBBIES.md)

## Autoría y créditos

**Matias Pulido · [1PKure](https://github.com/1PKure)**

Recursos de Argentum Online / AO20: Noland Studios y autores originales. El código utiliza [GNU AGPL-3.0](LICENSE); los recursos conservan sus licencias y créditos de origen.
