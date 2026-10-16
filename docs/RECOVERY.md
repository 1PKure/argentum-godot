# Recuperación de recursos y perfil de arena

La rama `work/ao20-spells` incluye recuperación autoritativa y un perfil explícito de prueba: 500 de vida y 3000 de maná. Permite pagar los costes originales de los hechizos caros. No representa una clase, nivel ni balance final de AO20. Los valores por defecto de PlayerState siguen sirviendo a fixtures independientes; el servidor aplica el perfil al conectar y reaparecer.

## Uso

- M o botón Meditar: inicia/detiene meditación. Espera inicial de 2 segundos; después recupera 5% del maná máximo por segundo. Se detiene al completar maná, moverse, golpear, lanzar, beber, recibir daño, morir o desconectarse.
- Q o botón de vida: usa una poción roja, +27 de vida.
- E o botón de maná: usa una poción azul, +5% del maná máximo.
- Las dos pociones también están en los primeros casilleros de Inventario; se usan con un clic.
- Reaparecer se habilita sólo al morir. Restablece el perfil, limpia efectos/cooldowns y coloca al personaje en un punto de aparición disponible.

Las pociones conservan los valores de OBJ38 y OBJ37 de `ao-org/Recursos/Dat/obj.dat`. `arena_consumables.ini` contiene esas secciones originales, no una copia de todo el inventario. El servidor comparte un intervalo de 380 ms entre colores y exige 800 ms después del golpe, tomados de `intervalos.ini`. No permite repetir la misma solicitud ni superar máximos. Rechaza beber con el recurso completo o estando muerto. La provisión de arena es ilimitada, siguiendo el uso libre en zonas de combate del servidor de referencia; no simula una cantidad de inventario.

La cadencia y cantidad de meditación son parámetros del prototipo: falta portar la fórmula completa por clase, skill Meditar y equipo de AO20. Se reutiliza su FX120 (MeditationLevelMax); el archivo público Meditaciones.dat refiere FX153 para niveles bajos, pero esa entrada no existe en el FXs.ini de la misma revisión. La selección de FX120 es una adaptación visual explícita.

## Red y comprobación

RecoveryNetwork usa solicitudes separadas de PlayerNetwork y determina al actor por el emisor real. Los clientes reciben estado y resultado del servidor, sin otorgarse recursos localmente. La versión 2 del protocolo de hechizos también exige el servidor actualizado para habilitar recuperación.

`tests/arena_recovery_smoke.gd` verifica datos, límites, intervalos, solicitudes repetidas, calentamiento, cadencia, interrupciones, muerte, reaparición y efectos de estado. `tests/arena_network_client.gd` usa botones y teclas con dos clientes reales para comprobar pociones, meditación/FX, remo, daño, cámara, catálogo, muerte y reaparición. La misma prueba se ejecuta con el PCK exportado.
