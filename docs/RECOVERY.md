> Actualización: el equipo y su orden ahora se validan en servidor y duran la sesión; cambiar de preset es libre y reconstruye sus objetos.

> Actualización de clases: 500 HP / 3000 MP corresponde ahora al Mago inicial. Las otras clases usan los perfiles de [CLASSES.md](CLASSES.md); las clases sin maná no meditan.

# Recuperación de recursos y perfil de arena

La arena incluye recuperación autoritativa y perfiles de clase; el Mago usa 500 de vida y 3000 de maná. Permite pagar los costes originales de los hechizos caros. Los valores son adaptaciones de arena, sin progresión de nivel ni balance final de AO20. Los valores por defecto de PlayerState siguen sirviendo a fixtures independientes; el servidor aplica el perfil al conectar y reaparecer.

## Uso

- M o botón Meditar: inicia/detiene meditación. Espera inicial de 2 segundos; después recupera 5% del maná máximo por segundo. Se detiene al completar maná, moverse, golpear, lanzar, recibir daño, morir o desconectarse. Ambas pociones se pueden usar sin detenerla ni reiniciar su calentamiento/cadencia. Si una poción azul completa el maná, la meditación termina en esa misma acción.
- Q o botón de vida: usa una poción roja, +27 de vida.
- E o botón de maná: usa una poción azul, +5% del maná máximo.
- Las dos pociones aparecen inicialmente en los primeros casilleros de Inventario; clic las usa y arrastrar las mueve a un casillero vacío o intercambia sus posiciones. Se guarda el orden por dispositivo; Q/E siempre usan el mismo tipo de poción, independientemente del casillero.
- Reaparecer se habilita sólo al morir. Restablece el perfil, limpia efectos/cooldowns y coloca al personaje en un punto de aparición disponible.

Las pociones conservan los valores de OBJ38 y OBJ37 de `ao-org/Recursos/Dat/obj.dat`. `arena_consumables.ini` contiene esas secciones originales, no una copia de todo el inventario. El perfil de arena comparte un intervalo de 330 ms entre colores y exige 700 ms después del golpe. Es una adaptación solicitada respecto de los 380/800 ms de referencia; `intervalos.ini` se conserva. Ver [ACTION_INTERVALS.md](ACTION_INTERVALS.md). No permite repetir la misma solicitud ni superar máximos. Rechaza beber con el recurso completo o estando muerto. La provisión de arena es ilimitada, siguiendo el uso libre en zonas de combate del servidor de referencia; no simula una cantidad de inventario.

La cadencia y cantidad de meditación son parámetros del prototipo: falta portar la fórmula completa por clase, skill Meditar y equipo de AO20. Se reutiliza su FX120 (MeditationLevelMax), ahora un 30% menor, anclado a los pies y por delante del cuerpo, con nombre y barras encima. El archivo público Meditaciones.dat refiere FX153 para niveles bajos, pero esa entrada no existe en el FXs.ini de la misma revisión. La selección de FX120 es una adaptación visual explícita.

## Red y comprobación

RecoveryNetwork usa solicitudes separadas de PlayerNetwork y determina al actor por el emisor real. Los clientes reciben estado y resultado del servidor, sin otorgarse recursos localmente. La versión 4 del protocolo de hechizos también exige el servidor actualizado para habilitar recuperación.

`tests/arena_recovery_smoke.gd` verifica datos, límites, intervalos, solicitudes repetidas, calentamiento, cadencia, interrupciones, muerte, reaparición y efectos de estado. `tests/arena_network_client.gd` usa botones y teclas con dos clientes reales para comprobar pociones, meditación/FX, remo, daño, cámara, catálogo, muerte y reaparición. La misma prueba se ejecuta con el PCK exportado.
