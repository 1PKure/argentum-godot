# Rendimiento web: suelo, minimapa e indicador legible

## Evidencia y alcance

La captura del usuario muestra AO original, 49 FPS, fotograma p95 24 ms y 2.830 draw calls. El ping RTT es 38 ms (p95 64), las confirmaciones de movimiento p50 58/p95 74 ms, el handler del servidor p95 0,3 ms, sin timeouts ni solicitudes pendientes y con cola visual actual cero/máxima dos. Esa muestra identifica un problema claro de renderizado; no basta para atribuirlo a una nueva falla de ruta de red. El RTT de aplicación incluye la espera del navegador para procesar mensajes cuando tarda un fotograma.

La última actualización de jugabilidad no modificó los pisos ni el motor del navegador. Los costos gráficos compartidos por ambos modos ya existían: el suelo enviaba comandos para una gran zona exterior y las líneas de los pisos y del minimapa se dibujaban por separado. La Sala de Duelos reproduce el valor reportado, incluso sin hechizos. No se presenta esta optimización como prueba de la fecha exacta en que empezó la regresión.

Se comparó el código publicado `060c5a7602564dc3eb0dbed113df98a194c0069e` contra el cambio con la misma escena de dos jugadores y el HUD completo, Godot 4.7.2 GL Compatibility, 1280×800, Mesa llvmpipe/Xvfb. Son presupuestos de dibujo nativos reproducibles, no FPS en hardware de jugadores:

| Escena completa | Antes | Después |
| --- | ---: | ---: |
| Bosque | 200 | 181 |
| Desierto | 989 | 183 |
| Lava | 1211 | 203 |
| Sala de Duelos | 2809 | 202 |
| Sala de Duelos + dos hechizos originales | 2817 | 210 |
| Sala de Duelos + dos hechizos modernos | 2817 | 210 |

Aislado, el minimapa de Sala de Duelos pasa de 501 a 4 llamadas; el de Lava de 498 a 4. La escena de Sala de Duelos sin HUD pasa de 2146 a 36. Las capturas comparadas de pisos mantienen diferencia RGB media inferior a 0,5/255 y ningún píxel con diferencia máxima superior a 20/255 en la zona comparada. El minimapa conserva forma, colores y marcadores; hay diferencias menores de rasterizado de líneas/círculos al agrupar la geometría.

## Cambios

- `ArenaCanvasBatch` agrupa rectángulos, líneas y decoraciones estáticas en meshes coloreados. El suelo conserva referencias a esos recursos durante la vida de los comandos del canvas. No se genera una textura gigante ni un viewport adicional.
- La cámara transmite su rectángulo visible al suelo. El intervalo de tiles se actualiza en bloques con margen para evitar huecos al moverse y reconstrucciones en cada fotograma. Los límites y colisiones del servidor no cambian.
- El minimapa conserva su geometría estática por arena y tamaño; solo cambian los marcadores de jugadores al recibir movimiento. Mantiene los mismos recursos gráficos y distribución.
- El indicador normal muestra una línea: `60 FPS · Ping: 38 ms`. No muestra p95, draw calls ni detalles de movimiento. Si no existe medición informa `midiendo…` o `sin respuesta`, sin inventar 0 ms. El menú conserva FPS y ping y ofrece Diagnóstico detallado aparte; el muestreo de fotogramas se activa solo para ese diagnóstico.
- El gateway explicita TCP_NODELAY en las dos direcciones del proxy WebSocket para no agregar espera de agrupación a paquetes pequeños. Es una medida de transporte, no una afirmación de que Nagle fuera la causa de los 38 ms. No cambia mensajes, seguridad, CORS, persistencia ni capacidad.

## Conexión y verificaciones

El servidor público devolvió salud 200. Se abrió una única conexión WSS válida desde Work, se recibió el paquete inicial Godot de cuatro bytes y se recibieron tres pongs. No se creó perfil, sala ni premio. Esa ruta usa el proxy soportado de Work y sus tiempos no representan Argentina. Para decidir si hace falta otro cambio de red hay que volver a medir desde el navegador del jugador después de mejorar el renderizado.

Pasaron 43 comprobaciones del indicador y cobertura de cámara a tres zooms y tres posiciones de cada arena; 12 de equipamiento/minimapa; 21 de cámara/movimiento; 28 de clásico; 31 de controles; 69 del libro de combate; 10 de diagnóstico; 33 de movimiento. Pasaron además la regresión de arenas, ambiente y FX originales. La comprobación de FX modernos resuelve sus 158 checks, aunque ese fixture preexistente emite un aviso de recurso retenido al cerrar; no se observó ese error en las pruebas renderizadas del juego.

La prueba sobre el PCK exportado y clientes con ventana pasó 136 comprobaciones (host 94, guest 20, solo 22), sin errores de runtime: controles, menús, combate, modo visual, chat y bot. El gateway pasó ocho pruebas de acceso/persistencia y una sesión de cinco clientes con 124 checks de salas y bot. El diagnóstico WebSocket correlacionó correctamente respuestas y un retraso de servidor inyectado de 200 ms. El test renderizado verifica un presupuesto de 350 llamadas por escena; la versión publicada anterior lo excede en cinco muestras y la nueva pasa las seis. Estos excedentes del baseline son del presupuesto gráfico, no fallos de protocolo.

Resultados en `docs/hosting/web-performance-20261024.json`. Reproducción: importar con Godot 4.7.2 y ejecutar `tests/render_budget.gd` con GL Compatibility y una pantalla; `AO_PERF_OUTPUT` permite guardar JSON y capturas. Los tests de lógica se ejecutan headless. El movimiento mantiene el intervalo actual de 155 ms; el test antiguo de cámara tenía expectativas fijas de 120 ms y ahora verifica la duración configurada.

## Publicación y siguiente medición

Primero subir el ZIP completo de rendimiento al Worker existente `ao-mini`, cerrar y recargar la web. Esto aplica todo el arreglo de gráficos y HUD sin reiniciar el dedicado. Probar Sala de Duelos y Lava con idéntico navegador, resolución y una sola pestaña de juego; registrar FPS/ping durante movimiento y combate en ambos modos.

El ajuste TCP requiere luego actualizar el dedicado al mismo SHA con `hosting/vps/update-game.sh`, durante mantenimiento y conservando la imagen anterior. Se puede evaluar primero la parte web para no confundir ambas variables. El ranking no se reinicia. Mantener ocho conexiones y un único escritor en Chile.

No se publicaron estos cambios automáticamente: el ZIP y el commit quedan preparados para la actualización manual desde los paneles del usuario. La validación final de FPS, audio y latencia de Argentina debe realizarse en su navegador. No contratar otro servidor ni cambiar de región basándose solo en esta captura.

## Feedback posterior

El usuario publicó el paquete de rendimiento y confirmó una mejora considerable. El siguiente ajuste de parálisis, meditación y sangre está en `docs/PARALYSIS_AND_EFFECTS.md`. La publicación del ajuste TCP en Vultr no se da por confirmada solo por esa devolución.
