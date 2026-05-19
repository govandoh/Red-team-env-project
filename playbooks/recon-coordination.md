# Coordinación con Blue Team — Reconocimiento

## Principio

Cada fase que genera tráfico notable debe ser comunicada al Blue Team **antes** de ejecutarse. El objetivo es que ellos puedan detectarla, no que sea una sorpresa que rompa el ejercicio.

## Formato del mensaje de notificación

Enviar al canal acordado (chat del equipo / grupo WhatsApp) antes de cada fase:

```
[RED TEAM — INICIO FASE N]
Fase     : <nombre de la fase>
Hora     : HH:MM
Técnica  : <descripción en una línea>
Target   : 172.20.0.20
Duración : ~XX minutos
Señal OK : Esperar confirmación del Blue Team antes de ejecutar vectores disruptivos
```

Ejemplo real:

```
[RED TEAM — INICIO FASE 6]
Fase     : DoS
Hora     : 14:30
Técnica  : Slowloris + HTTP flood + SYN flood secuenciales
Target   : 172.20.0.20 (puerto 80)
Duración : ~25 minutos incluyendo pausas
Señal OK : Confirmar cuando estén monitoreando con Wireshark/ntopng
```

## Fases que requieren coordinación previa

| Fase | Nivel de coordinación requerido |
|------|--------------------------------|
| Fase 1 — Recon | Informar, no requiere confirmación |
| Fase 2 — Scanning | Informar, no requiere confirmación |
| Fase 3 — Enum | Informar, no requiere confirmación |
| Fase 4 — Creds | Informar y esperar ACK |
| Fase 5 — Exploit | Informar y esperar ACK |
| **Fase 6 — DoS** | **Confirmación escrita obligatoria** |
| Fase 7 — Post | Informar después |

## Señal de abort

Acordar de antemano cuál es la señal de abort (p. ej. la palabra "ABORT" en el canal). El Red Team detiene inmediatamente el vector activo al recibirla.
