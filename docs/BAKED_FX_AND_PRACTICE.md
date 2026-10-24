# Magia precalculada y controles de práctica

Moderna reproduce37atlas a24fps generados desde ArenaSpellVisual, con su
diseño procedural anterior, SpriteFrames/Texture compartidos y reproducción
independiente. Original AO conserva sus sprites/tiempos. La meditación conserva
el perfil dorado actual. Los27hechizos del libro están incluidos.

Los PNG ocupan6.5MB; todas las texturas RGBA sin mipmaps suman63.7MiB. Al conectar
en Original no se cargan; al elegir Moderna se precargan antes de aplicar la
preferencia. tools/modern_fx/run_bake.py regenera los atlas desde Godot/Xvfb y
corrige a alpha recto con Python/Pillow/NumPy; --metadata-only verifica límites
sin cambiar los PNG. Los renderers procedurales quedan como fuente/benchmark.

La prueba nativa de dos Apocalipsis reduce1222llamadas de dibujo a6 (igual que
Original AO), incluidos personajes. No son FPS de navegador. La comparación
del mismo instante arroja diferencia RGB media0.106/255 y máxima4/255 por
cuantización. La prueba de navegador continúa pendiente en el equipo del usuario.

El anfitrión solo puede reiniciar o quitar el bot durante combate/pausa.
Reiniciar restaura presets y arranca una cuenta de3s con nueva ronda; quitar
limpia bot y pausa y vuelve a preparación. Ninguno otorga puntos/recompensas.
En PvP se rechaza. El menú elimina Volver al lobby y mantiene Salir de la sala.

Bot: movimiento132→124ms; pociones300→280ms, reacción120–180ms. Curar se revisa
cada3.4–4.2s bajo55%HP, probabilidad60%, y posterga pociones550ms tras éxito.
Magia conserva1250ms, costos reales y prioridad Apocalipsis/Descarga, Tormenta
como último recurso y su reducción10% de daño de la revisión anterior.
