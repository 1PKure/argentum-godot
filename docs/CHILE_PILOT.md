# Piloto de AO Mini en Chile

## Estado verificado el 23 de octubre de 2026

El usuario eligió y creó un único VPS Vultr High Frequency de 1 vCPU / 1 GB en Santiago de Chile. No se provisionó São Paulo ni se agregaron backups u otros complementos pagos. El costo real de cómputo se consulta en su panel; no confundir apagar la instancia con detener la facturación.

El dedicado ejecuta el juego del commit `3cb49ab448f9381eb473cbf89cd9f5c892e46d1e`. Caddy termina HTTPS/WSS y publica solamente 80/443. Godot y la API interna de persistencia mantienen loopback dentro del contenedor; los puertos de la arena no se publican en el host. Compose tiene proyecto `ao-mini`; sus volúmenes de TLS deben conservarse.

Render Virginia está suspendido. Solo el dedicado de Chile escribe en Supabase. Las credenciales se generaron dentro del VPS mediante `hosting/vps/prepare-pilot.py`, con `.env` exclusivo y permisos 0600. La invitación de cliente y la clave del almacenamiento son distintas; la segunda nunca fue transferida al navegador ni al repositorio. La función de almacenamiento acepta únicamente la credencial rotada de Chile. Para volver a Render haría falta rotar de nuevo la autorización, detener Chile y reactivar un único escritor.

La configuración de la web privada ya apunta a Chile. Se mantuvo el acceso exclusivo del propietario, la capacidad de ocho conexiones y el homenaje a milusita con 9.999.999.999 puntos. No se amplió la audiencia durante estas pruebas.

## Validación remota

Resultados numéricos: [chile-validation-20261023.json](hosting/chile-validation-20261023.json).

- 124 comprobaciones nativas sobre el WSS público: dos salas simultáneas, snapshots y combate aislados, chat de lobby/juego, Listo, cuenta regresiva, bot, pausa, salida y cambios de mapa.
- Ocho conexiones reales y cuatro salas durante 300 segundos. Cada cliente envía movimiento cada 150 ms, curación propia cada 1050 ms, poción azul cada 300 ms y chat cada 1500 ms. Acciones fuera del intervalo pueden ser rechazadas correctamente por la autoridad.
- 14.470 movimientos aceptados, 26 bloqueados y cero timeouts de movimiento/ping; 1.078 eventos de hechizo recibidos.
- Novena conexión rechazada por capacidad; recuperación de una conexión al liberar las ocho anteriores.
- Invitación incorrecta y origen no permitido rechazados; ranking inaccesible sin invitación y CORS limitado al origen autorizado.
- Reinicio real del contenedor dedicado: WSS volvió a conectar y la respuesta completa del ranking coincidió con la capturada antes del reinicio (revisión 12, tres entradas).
- 21 pruebas del frontend y cuatro del gateway/persistencia local pasaron. La prueba inicial de clientes no pudo arrancar porque faltaba importar el checkout local; después de importar, la ejecución remota completa pasó. No fue un fallo del VPS.

Los clientes sintéticos usaron una sola identidad QA compartida para no crear ocho cuentas de prueba. La cuenta `QA_carga` queda con cero puntos y cero victorias; no se reinició ni se concedieron victorias artificiales al ranking real. Esto prueba ocho transportes/instancias de juego y cuatro salas, no ocho registros de cuentas independientes.

Work ejecutó clientes nativos sin renderizado y salió por su proxy HTTPS soportado. Todas las conexiones ascendentes validaron TLS y atravesaron el gateway público real. Sus RTT de 200–290 ms describen esa ruta, no la de Argentina. La captura del usuario en navegador mostró 180 FPS, RTT 33 ms (p95 39 ms) y confirmación de movimiento p50 34 / p95 39 ms. La prueba de carga no verifica audio, GPU ni sesiones humanas de varias horas.

En una muestra durante la carga, arena consumía 214,6 MiB y 6,57% de un núcleo; Caddy 47,11 MiB y 0,98%. No tratar una muestra como máximo ni como promedio de toda la sesión. Estos resultados justifican una beta acotada a ocho conexiones; no certifican capacidad mayor ni disponibilidad continua.

## Repetir sin exponer credenciales

Importar primero el proyecto con Godot 4.7.2 (`--headless --editor --path <repo> --import`). Instalar la dependencia Python `websockets` 16+ desde su distribución oficial. El runner lee el archivo privado de configuración del despliegue; nunca lo copia al informe.

```text
python tests/run_hosted_validation.py --godot <godot-4.7.2> --config <arena-config-privado.json> --identity <ruta-privada-fuera-del-repo.json> --output <carpeta-nueva> --seconds 300
```

La identidad QA se conserva fuera del repositorio para repetir sin crear nuevas cuentas. Los resultados contienen solo métricas y comprobaciones; los archivos de usuario con credenciales no deben subirse a GitHub. El runner no reinicia el dedicado: el reinicio controlado se realiza por separado cuando las salas estén vacías, comparando el ranking antes/después.

## Dirección de la beta

El usuario eligió un subdominio gratuito. Propuesta: proyecto `ao-mini` en Cloudflare Pages, que entregaría `ao-mini.pages.dev` si está disponible. El nombre no se considera reservado hasta obtenerlo del proveedor. El dedicado continúa en Chile y Supabase conserva la persistencia.

El frontend actual ocupa aproximadamente 30 MiB, con un archivo máximo de 19 MiB; cabe en el límite documentado de 25 MiB por archivo para Pages Direct Upload. Conservar el loader del WASM comprimido y su tipo `application/gzip`. Al publicar en otro origen, configurar CORS/WSS con ese origen exacto y volver a probar desde navegador. No habilitar un comodín de orígenes.

La subida/publicación de un frontend alternativo no debe copiar claves de almacenamiento, credenciales de Sites ni configuraciones privadas de prueba. Antes de abrir la beta, confirmar la URL emitida, ajustar el origen permitido, verificar descarga/sonido/navegación, y aprobar la ampliación de audiencia. No activar servicios pagos ni registrar un dominio con costo sin autorización.
