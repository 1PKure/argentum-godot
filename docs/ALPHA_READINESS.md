# AO Mini: revisión para pasar del gameplay a la web

## Decisión

El alcance funcional de gameplay puede cerrarse como alpha tras la prueba
manual del último ajuste del bot. La dificultad percibida no se deduce de
los tests: quedan los parámetros registrados para retocarlos con jugadores,
sin bloquear el trabajo de la página. No se declara una versión de producción.

## Flujo implementado y comprobable

- Nueve clases con equipo/presets, inventario y macros configurables; combate
  manual, magia, melee, arco, recuperación y controles remapeables.
- Salas PvP1v1 aisladas: crear/unirse, nick, arena, listo, cuenta y duelo;
  salida, desconexión, resultado, fantasma y revancha sin salir de la arena.
- Práctica con bot solo cuando falta el segundo humano; pausa, reinicio y
  retirada incluso en combate; cancelaciones sin recompensas indebidas.
- Chat de sala/partida, skins por clase, ranking y menú de volumen.
- Cuatro arenas, HUD aprobado, gráficos originales o atlas modernos;
  exportación web real. El rendimiento y audio finales requieren navegador.

La regresión funcional usa servidor y clientes nativos reales sobre el pack
exportado, además de pruebas de reglas, aislamiento, recuperación y UI.
Una salida de audio Dummy verifica disparadores/configuración, no escucha.
Las mediciones de atlas nativo no sustituyen un perfil de FPS en navegador.

## Prioridad de la próxima etapa

1. **Conectividad y hosting remoto gratuito.** La página privada sirve el
   cliente, pero el dedicado sigue siendo local y el WSS precargado apunta a
   127.0.0.1. El enlace por sí solo no habilita partidas entre otras PCs.
   Probar WSS real y dos navegadores en redes diferentes antes de invitar
   jugadores; medir latencia, desconexión y estabilidad prolongada.
2. **Persistencia.** Resolver durabilidad y respaldo del ranking/progreso
   antes de elegir un host de disco efímero. El ranking web actual depende
   del cliente conectado; falta refresco independiente desde el servidor.
   No hacen falta cuentas para esta alpha; autenticación y base de datos
   continúan siendo opcionales. El presupuesto autorizado es cero.
3. **Página y validación final.** Construir sobre la identidad AO Mini ya
   aprobada, conectar el flujo real de jugar/ranking y validar audio, FPS,
   carga, controles y revancha en navegadores de los testers. Conservar la
   audiencia privada; cualquier apertura de acceso requiere aprobación.

## Fuera del cierre actual

Especialidades futuras (p.ej. puñalada por espalda), nuevas skins/mapas y
ajustes finos de balance siguen como iteraciones posteriores. PvE está
descartado. No hacen falta más rediseños de HUD ni nuevas mecánicas para
comenzar la etapa de web. Capacidad de un proveedor y costo cero sostenible
no están demostrados por las muestras locales de carga; ver HOSTING_BUDGET.md.
