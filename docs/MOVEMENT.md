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

Los cambios de dirección y soltar/reapretar una tecla conservan el intervalo
pendiente. Antes, girar 60 ms después de un paso enviaba una solicitud prematura
que el servidor rechazaba, y recién volvía a intentar 120 ms más tarde. Ahora
la nueva dirección sale cuando termina el intervalo original: no agrega esa
pausa ni permite acelerar al alternar teclas.

El primer envío inicia un intervalo completo. El tiempo que pasó antes de ese
envío, por ejemplo un primer frame de 40 ms al abrir el cliente, no adelanta la
segunda solicitud. Esto evita la secuencia de un paso ligeramente adelantado y
el siguiente descartado que se detectó en la prueba WebSocket.

La presentación guarda los puntos de giro ya confirmados. Si llega una segunda
posición antes de terminar la primera, el avatar completa la esquina en lugar de
cruzar en diagonal hacia el último destino. El remanente del frame se aplica al
siguiente tramo, manteniendo 120 ms por casilla. No inventa posiciones futuras.

## Cámara de seguimiento

`ClientWorld.configure_viewport(size)` activa el seguimiento y escala el mapa a
su tamaño nativo. `resize_viewport(size)` actualiza el centro cuando cambia el
área de juego. El HUD llama a estas funciones con el tamaño local de `game_area`;
la escala global de la interfaz se aplica por herencia.

La cámara desplaza solamente el mundo dentro del Control que lo recorta, después
de la interpolación de los avatares. El centro de la casilla del jugador local
permanece en el centro del área de juego; interfaz, consola y botones no se
mueven. También sigue al jugador en los bordes, por lo que puede verse exterior
de la arena de 20×12 casillas: el mapa y sus colisiones no se ampliaron.

El apuntado transforma las coordenadas del puntero con la inversa global del
mundo. Sigue funcionando después de caminar, cambiar resolución o escalar la
interfaz. Desconectar elimina el objetivo y reconectar sigue al nuevo avatar.

## Comprobación

Ejecutar con Godot 4.7.2 desde la raíz del proyecto:

```text
godot --headless --path . --script tests/movement_smoke.gd
godot --headless --path . --script tests/camera_movement_smoke.gd
```

La prueba comprueba la repetición sostenida a 20/30/60/75/144 FPS, soltar/cambiar dirección,
la recuperación de un frame largo, el límite de velocidad ante solicitudes cada
milisegundo, los cambios simultáneos de dirección y la interpolación de una
posición confirmada. También verifica el registro real del servidor: tolerancia,
ocupación por otro jugador, obstáculos y límites del mapa.

La prueba de cámara comprueba el seguimiento a mitad de paso, los bordes,
redimensionar y reconectar, la conversión del puntero sobre personajes y suelo
tras el desplazamiento, los giros sin diagonales y el intervalo al cambiar de
tecla. No depende de que un contador de movimiento coincida con su implementación:
comprueba posiciones visibles y destinos que el servidor ya confirmó.

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
