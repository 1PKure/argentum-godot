# Movimiento por grilla

El movimiento continúa siendo autoritativo: el cliente solicita una dirección y
el servidor comprueba el intervalo, los límites, los obstáculos y la ocupación.
El avatar sólo avanza hacia posiciones que el servidor ya confirmó.

## Fluidez de la repetición

Antes el cliente reiniciaba un temporizador de 140 ms después de cada envío,
mientras el avatar recorría una casilla en 120 ms. A 60 FPS el envío terminaba
ocurriendo aproximadamente cada 150 ms, dejando una pausa visible al final de
cada paso. El tiempo sobrante de cada frame se perdía en cada repetición.

Ahora cliente, servidor y animación comparten el intervalo de 120 ms de
`MovementRules`. El cliente conserva el remanente entre frames y envía como
máximo una solicitud por frame. Después de un frame largo descarta las
repeticiones atrasadas: no intenta recuperar movimiento con una ráfaga. A baja
tasa de frames limita el remanente al margen que el servidor puede aceptar,
evitando que una repetición descartada agregue una pausa de un paso entero.

El servidor permite hasta 20 ms de adelanto para absorber la cuantización de
un frame a 60 FPS y pequeñas variaciones de entrega. Una solicitud temprana
conserva la fecha lógica programada para el paso; esa tolerancia no se resta de
nuevo al siguiente intervalo. Mantener o alternar teclas no permite acumular
velocidad ni realizar dos pasos al mismo tiempo.

## Comprobación

Ejecutar con Godot 4.7.2 desde la raíz del proyecto:

```text
godot --headless --path . --script tests/movement_smoke.gd
```

La prueba comprueba la repetición sostenida a 20/30/60/75/144 FPS, soltar/cambiar dirección,
la recuperación de un frame largo, el límite de velocidad ante solicitudes cada
milisegundo, los cambios simultáneos de dirección y la interpolación de una
posición confirmada. También verifica el registro real del servidor: tolerancia,
ocupación por otro jugador, obstáculos y límites del mapa.

`tests/movement_network_smoke.gd` prueba una conexión WebSocket real en el puerto
local 7789. Se ejecuta en dos procesos a 60 FPS: el primero con el argumento de
usuario `--movement-server` y el segundo sin él. Comprueba la secuencia de tiles,
los intervalos recibidos y la parada al soltar la tecla. La prueba de red de
hechizos comprueba también movimiento con la interfaz y el apuntado activos.

Esto reduce las pausas regulares de la implementación anterior. No incorpora
predicción local, compensación de latencia ni un búfer de interpolación para
Internet. El inicio de cada paso sigue dependiendo de la respuesta del servidor;
las pausas grandes por red o un navegador en segundo plano pueden seguir siendo
visibles. La sensación final requiere una prueba manual en el navegador de uso.
