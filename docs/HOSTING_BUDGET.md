# Presupuesto inicial de web, cuentas y servidor

Estimación orientativa consultada el 16 de octubre de 2026, en USD y antes de impuestos. No se ha contratado ni configurado ningún servicio nuevo. La demo actual conserva acceso privado y el dedicado sigue ejecutándose en la PC del desarrollador.

Son tres componentes distintos: la web/export de Godot, la autenticación y base de datos de cuentas/perfiles/resultados, y el servidor Godot dedicado que procesa el combate en tiempo real. El movimiento y cada golpe no deben convertirse en escrituras de base de datos; se persisten datos de cuenta, preferencias y resultados autorizados por el servidor.

| Componente | Referencia actual | Uso previsto |
| --- | --- | --- |
| Web estática/cliente | Cloudflare Pages publica solicitudes estáticas gratuitas e ilimitadas; las funciones tienen cuotas propias. | Opción para un alojamiento futuro bajo nuestra cuenta, conservando control de audiencia. No es una cotización ni un cambio del alojamiento privado actual. |
| Cuentas y Postgres administrados | Supabase Free: USD 0, 500 MB de DB y 50.000 usuarios activos mensuales incluidos; puede pausarse tras una semana de inactividad y no incluye backups automáticos. | Desarrollo y pruebas acotadas. El uso y límites deben revisarse antes de abrir la web a más personas. |
| Cuentas y Postgres administrados de pago | Supabase Pro desde USD 25/mes, con un primer proyecto Micro cubierto por créditos de cómputo y backups diarios de siete días. | Referencia de costo para una primera publicación pequeña con persistencia administrada. Los excesos y complementos se cobran aparte. |
| Servidor dedicado Godot | Akamai/Linode publica VPS compartidos desde USD 5/mes (1 GB). | Es sólo el precio de entrada, no una medición de capacidad de esta arena. Reservaría inicialmente USD 10–20/mes como presupuesto de prueba; región, RAM/CPU, bots y jugadores simultáneos se validan con mediciones. |

Mi estimación de presupuesto es aproximadamente USD 10–20/mes para pruebas remotas con DB/auth gratuitos, o USD 35–50/mes con el plan administrado de pago y un VPS pequeño. No garantiza una cantidad de jugadores. No incluye dominio, correo transaccional, impuestos, almacenamiento/transferencia adicionales, backups del VPS ni trabajo de mantenimiento. Es una referencia inicial, no el costo de un lanzamiento masivo ni una tarifa cerrada.

Antes de elegir el VPS hay que medir latencia desde Argentina y carga real del dedicado; una región barata y distante puede perjudicar el combate. La necesidad se mide por concurrencia y actividad, no sólo por cantidad de cuentas registradas. Puede mantenerse acceso por invitación durante las pruebas. Registro/login no implica publicar el proyecto ni abrir registros sin autorización.

Fuentes oficiales consultadas:

- [Cloudflare Pages: precios](https://developers.cloudflare.com/pages/functions/pricing/).
- [Supabase: planes, autenticación y base de datos](https://supabase.com/pricing).
- [Akamai/Linode: cómputo y precios](https://www.akamai.com/cloud/pricing).
