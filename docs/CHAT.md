# Chat de sala

El lobby muestra un panel lateral con conversación, mensaje y Enviar. En combate,
Enter o el botón Chat del registro abre el campo; Enter envía y Escape cancela.
El texto aparece en el registro superior (filtro Todo) y sobre el personaje.
Escribir bloquea acciones locales y cancela el cursor de lanzamiento para evitar
movimiento, macros, golpes o pociones accidentales; no pausa el combate.

El chat se comparte sólo entre los miembros de la sala. No hay chat global en el
directorio, mensajes privados, cuentas nuevas, almacenamiento persistente ni
servicios externos. Se conservan hasta30 mensajes en memoria por sala, también al
pasar del lobby al duelo. Entrar a otra sala limpia el historial del cliente;
cerrar una sala elimina su conversación del servidor. Un recién llegado puede
ver el historial actual de esa sala, sin reproducir burbujas antiguas.

El servidor usa la membresía actual y el nick de su registro, nunca un nombre
aportado por el envío. Exige ID de sala actual, nonce creciente, mensaje no vacío,
máximo160 caracteres y al menos800ms entre envíos por jugador. Normaliza saltos de
línea/tabulación a espacios y descarta controles de texto/direccionales. Los
mensajes se dibujan como texto literal, incluidos corchetes o etiquetas. El cliente
confirma envío con respuesta de autoridad; un rechazo conserva el borrador.

Una única capa de texto por personaje sirve para chat y palabras del hechizo.
Chat dura4s y las palabras del hechizo1,25s, con desvanecido final; la última
intervención reemplaza a la anterior. Las etiquetas siguen la posición interpolada
real del avatar. Si se cruzan los rectángulos de textos, el del jugador local se
ubica por encima con separación. Desaparición/reconstrucción de avatares limpia
las etiquetas. Los efectos visuales y el feedback de daño se conservan.

Protocolo24. GitHub Desktop: Pull de work/arena-lobbies, reiniciar
`tools/Start-PrivateWebTest.cmd` y Ctrl+F5 en la misma web privada. La siguiente
etapa es probar esta versión en navegador y después trabajar la página; no se
introducen preparativos de hosting que requieran pagos o cuentas.

Pruebas: `tests/chat_smoke.gd` cubre validación, rate limit, historial acotado,
limpieza, seguimiento, separación y reemplazo/expiración del texto. Las suites
`tests/run_lobby_network.py` y `tests/run_lobby_native.py` ejercitan chat real entre
clientes, ausencia de filtraciones entre salas, envío desde lobby/duelo, teclado,
botón Enviar, cancelación y bloqueo de acciones mientras se escribe.
