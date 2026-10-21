# Efectos modernos ligeros · PR12

21 de octubre de 2026. El usuario confirmó que en su navegador los efectos originales funcionan sin los tirones observados con la versión procedural. El nuevo modo «Moderna ligera» reutiliza las animaciones AO originales y su silueta, con un shader canvas_item compartido de contraste, saturación y realce de color. Meditación usa el atlas original con acabado dorado. Se trata de un retoque ligero, no de arte completamente nuevo.

## Implementación y comparación

El selector Menú → Magia conserva Original AO y sustituye el modo moderno costoso por Moderna ligera. Nativo tiene moderno por defecto; web conserva original salvo preferencia guardada. El viejo renderer procedural queda como referencia fuera del flujo de combate. Daño, hechizos permitidos, intervalos y audio no cambian por el modo visual.

Un AnimatedSprite2D por impacto; frames, atlas, bases visibles y materiales cacheados/compartidos. El shader usa el color de la textura, preserva alfa, no consulta la pantalla ni vecinos, no contiene bucles, y no genera geometría por frame. No añade nodos de partículas ni glow con múltiples capas. Shader estático: el acabado no sigue animándose al pausar. Atlas y shader se preparan durante la carga antes de conectar; la compilación gráfica se omite en headless. El anclaje a pies, seguimiento del objetivo y palabras del lanzador se conservan. La animación de meditación se pausa al ocultarse.

`tests/web_fx_render_compare.gd` mantiene una referencia de la implementación vieja y compara baseline/modern(original procedural)/original/modern_light. Linux GL Compatibility, Mesa llvmpipe, Xvfb,1280×800, dos avatares y dos Apocalipsis;30frames de calentamiento y120 muestras por modo. Sin HUD, audio, red ni navegador. Datos en `docs/hosting/native-fx-comparison-light.json`.

| Modo | Mediana draw calls |
|---|---:|
| Procedural anterior |1222|
| Original AO |6|
| Moderna ligera |6|

Esto mide trabajo de dibujo de esa escena. Los tiempos de cuadro del JSON dependen del render por software/carga del contenedor y no representan Chrome/Opera. El shader puede tener distinto costo de GPU aun con igual número de llamadas. La prueba final en el navegador del jugador sigue pendiente; no se ejecutó browser E2E en esta entrega.

FPS/p95 de hasta600 intervalos reales y draw calls siguen disponibles con Mostrar rendimiento. La ventana se limpia al cambiar de modo; no se usa latencia de red como FPS.

## HUD compacto

Tres filas de inventario visibles y mínimo18 casilleros. Se ocultan filas vacías posteriores; las42 posiciones del servidor se conservan para no perder objetos o diseños guardados. Si un objeto ocupa una posición posterior, se hace accesible con scroll. Recursos12px debajo del panel activo, vida sobre maná, sin espacio reservado al estado si está vacío. Menú/Desconectar tienen su propio cuadro12px debajo. El lateral termina debajo de sus botones, sin el antiguo fondo vacío. El libro de hechizos conserva su espacio para jugar con Lanzar.

## Ajuste del bot

Se mantienen las rojas del jugador en27HP y su cadencia. El bot pasa de280 a320ms entre pociones, reacción inicial160–240ms. Con una roja que lo deja por debajo de45%HP, retrasa ofensiva350ms: prioriza recuperar antes de volver a presionar. La curación mágica se considera bajo45%HP, con45% de decisión y revisión cada4,5–5,5s; no se encadena dentro de1,6s después de una roja. Si usa curación, posterga pociones1,6s. Remover y los combos legales por clase se conservan. No se cambian velocidad, daño o defensas.

Pruebas:144 comprobaciones de modo moderno/atlas/material compartido/factory/anclaje;242 de original;45 de compromiso de recuperación del bot;72 de práctica y27 de tácticas. La simulación de intercambio con flechas registra15 flechas,8 represalias y44 pociones del bot: sigue atacando y recuperándose, sin demostrar dificultad adecuada para todos los jugadores. 119 comprobaciones GUI (88host/17guest/14solo) de HUD y controles sobre PCK exportado con clientes nativos, más tests de sitio/integridad. Se revisaron capturas de los efectos y HUD. La valoración de estética, dificultad y rendimiento real de navegador requiere feedback del jugador.

## Probar

GitHub Desktop → work/arena-lobbies → Pull. Reiniciar el dedicado actualizado, recargar la web privada con Ctrl+F5 y elegir Menú → Magia → Moderna ligera. Comparar misma arena/ventana/navegador y un solo cliente con sonido, usando doble Apocalipsis, Descarga, Tormenta, curación y meditación. También sigue disponible Original AO. No se amplió audiencia ni contrataron servicios.

Referencia del shader: https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html
