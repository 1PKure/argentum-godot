# Comparación de efectos en PR12

21 de octubre de 2026. Reporte del usuario: el desplazamiento es fluido en web, pero al lanzar Apocalipsis se traban animación y sonido. La grabación no permite medir FPS reales ni demuestra que la red sea la causa. Las pruebas de carga del dedicado tampoco miden el costo de dibujar el cliente.

## Cambio reversible

La web comienza con efectos originales AO (hechizos y meditación), salvo preferencia local explícita. Nativo conserva Moderna por defecto. Menú → Magia alterna Original AO / Moderna sin cambiar daño, intervalos, maná, reglas, servidor o protocolo24. El modo se guarda en `user://visual_settings_v1.cfg`; `--fx-original` y `--fx-modern` permiten pruebas nativas sin guardar cambios. No se eliminaron efectos modernos, interfaz, personajes, pociones, biomas ni equipamiento.

Los originales usan atlas existentes con cuadros compartidos/cacheados, manteniendo avance por tiempo, impacto anclado a pies y seguimiento del objetivo. Textos siguen al lanzador. Los atlas y bases visibles se preparan una vez al iniciar el cliente, distribuidos entre frames de carga antes de conectar. Meditación original en bucle; al cambiar de modo se actualiza la meditación activa. El modo de un hechizo ya lanzado se conserva hasta terminarlo. No se alteraron WAV, ganancias, mezcla, Stream, voces ni latencia: se cambia una variable para aislar el costo visual.

Mostrar rendimiento se activa inicialmente en web y se puede apagar. Muestra FPS de Godot, p95 de intervalos reales entre frames (hasta600 muestras, reiniciadas al cambiar de modo) y llamadas de dibujo del cuadro. No envía datos ni mide ping; las pausas o cambio de pestaña también afectan estos tiempos. Un p95 alto indica cuadros lentos, no prueba una causa específica.

## Evidencia nativa

Runner: `tests/web_fx_render_compare.gd`, con `AO_UI_CAPTURE_DIR` apuntando a una carpeta. Usa GL Compatibility/Mesa llvmpipe/Xvfb,1280×800, dos avatares y dos Apocalipsis animados;30frames de calentamiento y120 muestras por modo. Baseline vacío. No incluye audio, servidor, HUD ni navegador. JSON en `docs/hosting/native-fx-comparison.json`.

Mediana de llamadas de dibujo:1222 moderno frente a6 original. Este resultado muestra una reducción importante del trabajo de dibujo de esa escena concreta. Los tiempos de cuadro nativos bajo render por software y carga compartida no son estimaciones de Chrome/Opera ni porcentajes garantizados de mejora en la PC del usuario. No se usó este benchmark para prometer FPS ni aforo.

## Prueba web requerida

1. Actualizar `work/arena-lobbies`, cerrar cualquier segundo cliente con sonido, reiniciar dedicado de prueba y recargar la misma web privada con Ctrl+F5.
2. En el mismo navegador, arena y tamaño de ventana: dejar Original AO, activar medidor, jugar30–60s y probar doble Apocalipsis, Descarga, Tormenta y curaciones. Observar primer lanzamiento y lanzamientos repetidos.
3. Alternar Moderna y repetir, dejando unos segundos de calentamiento tras cambiar. Comparar medidor, fluidez y sonido sin cambiar otras opciones simultáneamente.
4. Si ambos fallan, repetir cada modo con General0% sólo como prueba de asociación. Silenciar no necesariamente detiene el trabajo del mezclador, por lo que no equivale a una prueba estricta sin reproducción de audio.

La evaluación de Sample frente a Stream queda separada: Godot documenta que Sample reduce la dependencia del hilo principal en web sin threads, pero tiene límites de efectos de bus y reproducción. Cambiarlo ahora a la vez impediría atribuir la mejora a los gráficos y exigiría validar pausas/volumen. Referencia: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html

## Validación

242 comprobaciones de atlas/caché/independencia/duración/anclaje/factory/audio/meditación/medidor;128 assets;210 identidad moderna;15 audio;25 HUD;26 lobby;49 gestos. 116 comprobaciones GUI nativas contra PCK exportado (85host/17guest/14solo) verifican además los controles reales del selector/medidor y flujo PvP/bot. El runner aísla datos/cachés de los procesos para evitar escrituras simultáneas de caché de shaders.

El intento de navegador automatizado agotó el tiempo de la herramienta antes de obtener una página; no se comprobó rendimiento en navegador. La prueba final de Chrome/Opera sigue pendiente. No se amplió la audiencia de la demo ni se añadieron servicios pagos.
