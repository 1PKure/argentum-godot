# Medición de conexión y movimiento

En Menú activar **Mostrar rendimiento**. El panel distingue:

- **Fotograma p95**: percentil 95 del intervalo entre frames locales; no es ping.
- **Ping RTT**: última ida y vuelta de una RPC por el mismo WebSocket del juego, con p95 de las últimas 60 respuestas. Incluye red y espera de procesamiento/poll del motor. No es un ping ICMP ni requiere relojes sincronizados.
- **Movimiento p50/p95**: tiempo desde enviar la orden hasta recibir la respuesta correlacionada de la autoridad. Solo incluye órdenes aceptadas, incluidas las que únicamente cambian orientación.
- **Servidor p95**: tiempo dentro del manejador de movimiento, medido en el servidor. No incluye esperas anteriores al manejador, ida/vuelta de red ni animación.
- **Confirmados/bloqueados**: el servidor confirma si aplicó la orden. Paredes, cooldown, parálisis, ronda inactiva o pausa pueden bloquearla; no representan pérdida de paquetes.
- **Sin confirmar/pendientes**: órdenes cuyo acuse venció a los cinco segundos / las que siguen esperando. Tampoco equivalen automáticamente a pérdida de paquetes de TCP.
- **Cola visual**: posiciones confirmadas que todavía faltan recorrer, junto con el máximo observado desde conectar o recuperar el foco.

Los probes se envían cada dos segundos. El servidor limita sus respuestas por cliente. Los mapas y las ventanas tienen límites de tamaño, las respuestas duplicadas o desconocidas no cuentan y las muestras se limpian al reconectar. Al perder foco se descartan órdenes pendientes de medición; al recuperarlo se comienza otra muestra para no atribuir la suspensión del navegador a la red. La simulación y los intervalos de movimiento conservan las reglas anteriores. No se implementa predicción en este cambio.

## Cómo evaluar

1. Entrar a práctica, activar el panel y mantener la pestaña enfocada.
2. Esperar al menos diez segundos, caminar recto, cambiar de dirección varias veces y detenerse. Capturar el panel después de 30–60 segundos.
3. Repetir desde la misma conexión con el dedicado local para tener una referencia comparable.
4. Ping alto con manejador rápido apunta al recorrido de red o a esperas fuera del manejador. Ping razonable con cola visual creciente apunta a revisar el seguimiento y la reproducción de posiciones. Un manejador lento merece perfilado del dedicado. Son indicios; hacen falta varias muestras y medición desde la conexión del jugador.

## Validación inicial

- 10 comprobaciones de correlación, vencimiento, percentiles y reinicio de sesión.
- 7 comprobaciones por WebSocket real con 200 ms de demora controlada antes del acuse. Resultado de esta ejecución: RTT local 7 ms; confirmación de movimiento 200,1 ms; el panel distingue ambas medidas.
- 124 comprobaciones con cinco clientes y el dedicado completo: dos salas y bot. El movimiento medido es aceptado durante la ronda y rechazado al pausar. Muestra local de la ronda: RTT 7 ms; confirmación p95 6,9 ms; manejador p95 0,1 ms.
- 33 comprobaciones previas de cadencia de movimiento sin cambios.

Estos números son pruebas locales, no una estimación de la latencia desde Argentina ni una promesa sobre otro hosting. Las muestras no se envían a una base de datos ni se guardan como historial de usuarios.
