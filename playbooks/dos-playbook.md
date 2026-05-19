# Playbook DoS — Red Team Lab

## Reglas no negociables

| Regla | Razón |
|---|---|
| Duración máxima por vector: **60–120 segundos** | Demostrar el vector sin destruir el servicio. |
| Solo dentro de `lab-net` (`172.20.0.0/24`) | Regla del proyecto. Los scripts rechazan targets externos. |
| Blue Team avisado **por escrito** y monitoreando | Sin detección coordinada, el ejercicio no cumple objetivos. |
| Pausa de **5 minutos** entre vectores | Permitir recuperación y revisión de logs del Blue Team. |
| Si el servicio cae > **3 minutos**, **abortar** | Margen de seguridad operativa. |
| Línea base **obligatoria** antes de cualquier ataque | Sin baseline, las métricas de impacto no significan nada. |

---

## Checklist pre-ventana

Antes de ejecutar `run-dos-window.sh`, confirmar cada punto:

- [ ] Blue Team notificado por escrito (chat/correo) con hora de inicio
- [ ] Ventana acordada: hora inicio y hora máxima de fin
- [ ] Canal de señal de abort establecido (p. ej. "ABORT" en el chat)
- [ ] `99-monitor.sh` corriendo en segunda terminal del Kali
- [ ] `start-pcap.sh` corriendo en el host para captura completa
- [ ] Stack Docker levantado y `ping 172.20.0.20` respondiendo

---

## Orden de ejecución

```
Terminal 1 (host):   sudo bash observability/start-pcap.sh
Terminal 2 (Kali):   docker compose exec kali bash
                     → bash /root/scripts/phase-6-dos/99-monitor.sh
Terminal 3 (Kali):   docker compose exec kali bash
                     → bash /root/scripts/phase-6-dos/run-dos-window.sh
```

| Paso | Script | Duración estimada |
|------|--------|------------------|
| 0. Baseline | `00-baseline.sh` | ~1 minuto |
| 1. Slowloris | `01-slowloris.sh` | 60 segundos |
| Pausa | — | 5 minutos |
| Recovery check | `recovery-check.sh` | ~20 segundos |
| 2. HTTP flood | `02-http-flood.sh` | 60 segundos |
| Pausa | — | 5 minutos |
| Recovery check | `recovery-check.sh` | ~20 segundos |
| 3. SYN flood | `03-syn-flood.sh` | 30 segundos |
| Pausa | — | 5 minutos |
| Recovery check | `recovery-check.sh` | ~20 segundos |

**Duración total estimada: ~20–25 minutos**

---

## Señal de abort

Si el Blue Team envía ABORT o el servicio cae más de 3 minutos consecutivos:

1. Presionar `Ctrl+C` en el terminal del vector activo.
2. Ejecutar `recovery-check.sh` manualmente.
3. Notificar al Blue Team que el ataque fue detenido.
4. Documentar en `notes.md` la razón del abort.

---

## Evidencia esperada al finalizar

Ver `playbooks/evidence-format.md` para el estándar completo.

Archivos mínimos por vector:

| Archivo | Vector |
|---|---|
| `baseline-curl.csv` | Todos |
| `baseline-ab.txt` | Todos |
| `slowloris.pcap` + `slowloris-report.html` | Vector 1 |
| `http-flood.pcap` + `http-flood-ab.txt` | Vector 2 |
| `syn-flood.pcap` + `syn-flood.log` | Vector 3 |
| `monitor-HHMMSS.csv` | Durante ataque |
| `recovery-check.csv` | Después de cada vector |
| `run.log` | Toda la ventana |
