> Actualización: el equipo y su orden ahora se validan en servidor y duran la sesión; cambiar de preset es libre y reconstruye sus objetos.

> Actualización de clases: 363 HP / 2487 MP corresponde ahora al Mago inicial. Las otras clases usan los perfiles de [CLASSES.md](CLASSES.md); las clases sin maná no meditan.

# Recuperación de recursos y perfil de arena

La arena incluye recuperación autoritativa y perfiles de clase; el Mago usa 363 de vida y 2487 de maná (humano, nivel 50). Permite pagar los costes originales de los hechizos caros. Los valores son adaptaciones de arena, sin progresión de nivel ni balance final de AO20. Los valores por defecto de PlayerState siguen sirviendo a fixtures independientes; el servidor aplica el perfil al conectar y reaparecer.

## Uso

- M o botón Meditar: inicia/detiene meditación. Espera inicial de 2 segundos; después recupera 5% del maná máximo por segundo. Se detiene al completar maná, moverse, golpear, lanzar, recibir daño, morir o desconectarse. Ambas pociones se pueden usar sin detenerla ni reiniciar su calentamiento/cadencia. Si una poción azul completa el maná, la meditación termina en esa misma acción.
- Q o botón de vida: usa una poción roja, +27 de vida.
- E o botón de maná: usa una poción azul, +5% del maná máximo.
- Las dos pociones aparecen inicialmente en los primeros casilleros de Inventario; clic las usa y arrastrar las mueve a un casillero vacío o intercambia sus posiciones. Se guarda el orden por dispositivo; Q/E siempre usan el mismo tipo de poción, independientemente del casillero.
- Reaparecer se habilita sólo al morir. Restablece el perfil, limpia efectos/cooldowns y coloca al personaje en un punto de aparición disponible.

Las pociones conservan los valores de OBJ38 y OBJ37 de `ao-org/Recursos/Dat/obj.dat`. `arena_consumables.ini` contiene esas secciones originales, no una copia de todo el inventario. El perfil de arena comparte un intervalo de 280 ms por vía, compartidos entre colores, un mínimo común de 200 ms al combinar clic/Usar y exige 600 ms después del golpe. Es una adaptación solicitada respecto de los 380/800 ms de referencia; `intervalos.ini` se conserva. Ver [ACTION_INTERVALS.md](ACTION_INTERVALS.md). No permite repetir la misma solicitud ni superar máximos. Rechaza beber con el recurso completo o estando muerto. La provisión de arena es ilimitada, siguiendo el uso libre en zonas de combate del servidor de referencia; no simula una cantidad de inventario.

La cadencia y cantidad de meditación son parámetros del prototipo: falta portar la fórmula completa por clase, skill Meditar y equipo de AO20. Se reutiliza su FX120 (MeditationLevelMax), ahora un 30% menor, anclado a los pies y por delante del cuerpo, con nombre y barras encima. El archivo público Meditaciones.dat refiere FX153 para niveles bajos, pero esa entrada no existe en el FXs.ini de la misma revisión. La selección de FX120 es una adaptación visual explícita.

## Red y comprobación

RecoveryNetwork usa solicitudes separadas de PlayerNetwork y determina al actor por el emisor real. El dueño recibe estado completo y resultado del servidor; otros jugadores reciben estado público sin maná actual, sin otorgarse recursos localmente. La versión 6 del protocolo de hechizos también exige el servidor actualizado para habilitar recuperación.

`tests/arena_recovery_smoke.gd` verifica datos, límites, intervalos, solicitudes repetidas, calentamiento, cadencia, interrupciones, muerte, reaparición y efectos de estado. `tests/arena_network_client.gd` usa botones y teclas con dos clientes reales para comprobar pociones, meditación/FX, remo, daño, cámara, catálogo, muerte y reaparición. La misma prueba se ejecuta con el PCK exportado.


## Poción seleccionada y Usar

Clic en una poción selecciona y bebe; un borde dorado marca la selección. El botón **Usar · Espacio** o la barra espaciadora usa esa poción. Mantener Espacio o Usar repite mientras haya un recurso por recuperar. La selección sigue a roja/azul al arrastrarla, no al número de casillero; cambiar equipo no selecciona un objeto como poción. Por sesión comienza elegida la roja. Q/E sigue disponible y comparte el intervalo de Usar.

La selección también funciona si el recurso está lleno: queda marcada y no bebe. Usar, clic y teclas de poción conservan el cursor del hechizo y la pestaña elegida. Se puede preparar un macro, potear y luego apuntar el hechizo. Meditar y las demás cancelaciones explícitas mantienen su comportamiento.

Clic + Usar es una combinación deliberada: cada vía tiene 280 ms y ambas respetan 200 ms entre consumos y el bloqueo de 600 ms tras golpe. El cliente puede esperar brevemente el momento válido, pero sólo el dedicado confirma el uso. No depende de una carrera entre paquetes. Ver [ACTION_INTERVALS.md](ACTION_INTERVALS.md).

La repetición se corta al soltar la tecla/botón. Menú, Clases, Bot, muerte, pérdida de foco y desconexión también cancelan entradas pendientes. No se reanuda al cerrar el menú con la tecla todavía apretada. Espacio escrito en búsqueda no usa objetos; elegir una acción de juego por clic libera el foco de texto.
