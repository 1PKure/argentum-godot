# Ajustes de tácticas y clics de interfaz

Las semimágicas usan Paralizar→golpe→Descarga. Se retiran Flecha Eléctrica y
Misiles de ambos caminos alternativos. Solo después de tres remates de
Descarga tras golpe se habilita Fuego Mágico/Tormenta si no alcanza el maná
para Descarga y la clase puede lanzarlos. Usar esa alternativa reinicia el
contador. La presión de magia a distancia aparece tras dos combos y tiene
20% de decisión por oportunidad. Al iniciar otra práctica se borra el contador.
El paso semimágico pasa124→140ms; Mago/Druida/Cazador mantienen124ms.

El mago conserva su apertura doble Apocalipsis. Al reconstruir maná puede
iniciar ofensiva con un presupuesto real Apocalipsis+Descarga (1460MP), en
vez de esperar siempre2000MP. Si para el segundo lanzamiento puede pagar
otro Apocalipsis lo prioriza; si no, busca Descarga. Primer compromiso450–650ms
tras la cuenta (antes600–850); error de puntero deliberado4% (antes6%).
Costos, percepción, intervalo mágico1250ms y recuperación permanecen iguales.

UIClickAudio registra BaseButton y PopupMenu existentes y futuros desde el
inicio del cliente. Genera una vez un PCM mono16bit/44100Hz de45ms, sin
assets externos; un reproductor compartido con3voces y guarda25ms evita
notificaciones duplicadas de una misma acción. No reproduce por hover,
refrescos o botones deshabilitados. El registro ocurre al entrar al árbol, sin diferir referencias a controles
que pueden destruirse al reconstruir menús. Se omite
el dedicado --server. El audio usa ArenaAudioMix/Efectos y por lo tanto
General/Efectos del menú, incluso en web Sample/Master. No se agregan buses
web ni se modifican los sonidos de combate/pisos.

La GUI nativa comprueba clics reales desde Crear sala y Menú de combate.
La prueba de audio comprueba conexiones únicas, controles transitorios,
deshabilitados, listas, PCM y margen de amplitud. La reproducción audible
final en el navegador requiere feedback del usuario; no se asume por tests
con salida Dummy. Gráficos/HUD permanecen aprobados.
