# Parálisis y efectos después de la optimización web

El usuario publicó el ZIP de rendimiento y confirmó una mejora considerable. Esta actualización conserva los meshes de suelo/minimapa y todos los intervalos de movimiento, golpe, magia y pociones del jugador.

## Reglas de estado y bot

Paralizar bloquea desplazamiento y cambios de orientación en el servidor. El bloqueo se aplica también a los giros directos del bot y a la orientación automática del cazador al disparar. Las acciones de combate y recuperación que estaban permitidas durante el estado siguen disponibles; no se agrega un silencio ni se bloquean pociones.

Inmovilizar mantiene el bloqueo de desplazamiento y permite girar con la cadencia autoritativa vigente. Conserva su costo de 300 de maná, frente a 375 de Paralizar. Los estados se distinguen mediante `locks_facing`; aplicar el estado más barato no borra una parálisis activa. Remover elimina ambos tipos de bloqueo como antes, y la expiración de Paralizar permite volver a girar aunque aún quede Inmovilizar.

El bot espera 1100–1400 ms desde que observa el bloqueo antes de intentar Remover, además de respetar su intervalo real de magia y el maná disponible. No intenta mover el personaje mientras está bloqueado. Reaplicar el estado no reinicia indefinidamente una reacción ya iniciada: se conserva su plazo, para no crear un bloqueo perpetuo al repetir el hechizo.

## Meditación

Se recuperó el remolino de cintas doradas/marfil del commit `041426b`. Su fuente está en `tools/meditation_fx/approved_source.gd`, con fases adaptadas a un ciclo continuo de cuatro segundos y escala de captura reducida. El runtime reproduce un atlas de 96 fotogramas a 24 FPS, no sus curvas procedurales. El PNG pesa 213337 bytes y ocupa 472×1476 píxeles (aproximadamente 2,66 MiB RGBA en GPU), compartido por todas las instancias. Se precarga junto a los efectos modernos.

El modo original limita la altura del sprite a 108 píxeles y el moderno a 128 píxeles (18,5 % más grande que su ajuste anterior); el contenedor del personaje mantiene escala 1.0. Se prueban los dos factores para evitar que vuelvan a multiplicarse. La variante original conserva el atlas AO, la moderna usa la animación dorada recuperada. Cambiar de perfil pausa el sprite oculto; ocultar la meditación detiene su reproducción y procesamiento.

Para regenerar: ejecutar `tools/meditation_fx/bake.gd` con Godot 4.7.2 GL Compatibility y una pantalla (por ejemplo Xvfb). Inmediatamente después ejecutar una sola vez `python3 tools/meditation_fx/finalize.py`, que transforma el framebuffer premultiplicado a alfa recta y cuantiza la paleta RGBA. Reimportar el PNG en Godot y verificar `tests/meditation_blood_render.gd`. Las herramientas de generación no se exportan al cliente.

## Sangre

El mismo efecto se usa para contactos confirmados de flecha y cuerpo a cuerpo. Se sustituyen los cuadrados rosas/gruesos por hasta diez gotas alargadas de rojo oscuro, orientadas según el impacto y con gravedad y desvanecimiento. Dura 0,38 s y utiliza un único mesh por efecto/fotograma, con referencia retenida mientras el canvas lo usa. No agrega sonidos ni modifica daños. Los fallos, evasiones y bloqueos no producen sangre.

## Verificación

- 24 comprobaciones de reglas: Paralizar en cuatro direcciones, diferencia con Inmovilizar, Remover real, cazador, las nueve clases del bot congeladas durante el primer segundo y ventana de reacción de Remover.
- 20 comprobaciones de meditación/sangre: perfiles distintos, caché compartida, tamaño del sprite y del contenedor, bucle, pausa y paleta acotada.
- Pruebas de estados, hechizos, movimiento, orientación, recuperación, tácticas del bot y sangre que sigue al objetivo. Las fixtures antiguas con duraciones fijas se ajustan a la cadencia actual y diferencian Inmovilizar de Paralizar.
- 124 comprobaciones con cinco clientes WebSocket en dos salas y práctica con bot. La prueba de orientación con actor/observador también pasa sin errores.
- 136 comprobaciones nativas con ventana sobre el PCK exportado: host94, guest20, solo22, sin errores de runtime.
- El presupuesto de dibujo anterior se mantiene: escena completa de Sala de Duelos202 llamadas, 210 con dos hechizos en ambos estilos. Galería con dos personajes meditando y tres impactos:26 llamadas. Son medidas nativas GL/Mesa, no una promesa de FPS de navegador.
- Las pruebas renderizadas de flecha y melee comparan imágenes con ambiente y pose congelados para no contar partículas del bioma como sangre. Verifican contraste y dispersión sobre varios atuendos, seguimiento, impacto y limpieza.

## Publicación

El ZIP conserva sitio, motor web, JavaScript, audio y endpoints públicos; cambia PCK y metadatos de versión. Subirlo al Worker existente `ao-mini`. Esta vez también hay que aplicar el mismo commit en Vultr con `hosting/vps/update-game.sh`, porque las reglas de parálisis y el comportamiento del bot son autoritativos. Hacerlo durante mantenimiento, cerrar y recargar clientes y comprobar salud y una ronda. No se reinicia el ranking ni se modifica la base de datos o la audiencia.

Estado: preparado y probado, pendiente de publicación manual. No se actualiza el servidor al subir un commit a GitHub.

## Corrección posterior: detener la interpolación del cliente

Se reprodujo una cola de seis pasos ya confirmados por el servidor: recibir un estado de parálisis o muerte no eliminaba esa cola visual. El cliente seguía recorriéndola aunque el servidor ya no aceptara desplazamientos. Esto explica movimiento aparente durante la parálisis y después de morir sin atribuirlo a una nueva decisión de la IA.

El avatar ahora cancela la cola y la animación de caminar inmediatamente al recibir Paralizado, Inmovilizado o la transición a muerto, y se coloca en el tile confirmado en ese estado. Un bot muerto permanece detenido; los fantasmas humanos pueden volver a desplazarse. El origen de coordenadas se obtiene del spawn, sin asumir una posición fija del mundo. El procesamiento de un paquete de movimiento aplica primero su estado para conservar el primer paso permitido después de Remover.

Pasan 14 comprobaciones nuevas con snapshots y eventos de ClientWorld: cola acumulada, parada, ausencia de pasos/sonidos posteriores, desbloqueo, giro al estar inmovilizado, muerte, fantasma humano y nueva ronda. También pasan 22 de meditación/sangre, 21 de cámara, 33 de movimiento, 18 de orientación, 18 de fin de ronda y 24 de reglas autoritativas. La galería renderizada conserva 26 llamadas de dibujo. Esta corrección es del cliente y no cambia reglas ni tiempos del bot; subir su nuevo ZIP al Worker es suficiente si el servidor ya tiene el ajuste de reglas anterior.
