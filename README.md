# Red Team Lab

Laboratorio de simulación de ataque y defensa en redes — Proyecto Final Redes 2, ciclo 2026.

**Rol:** Red Team (ofensiva)  
**Metodología:** PTES simplificado (Recon → Scan → Enum → Exploit → DoS → Post → Report)  
**Target:** Metasploitable2 en `172.20.0.20` dentro de red aislada `lab-net`

---

## Quickstart

```bash
# 1. Levantar el stack (Kali + Metasploitable2)
cd docker
docker compose up -d

# 2. Verificar que el target responde
docker compose exec kali ping -c 3 172.20.0.20

# 3. Entrar al Kali
docker compose exec kali bash

# 4. (Opcional) Activar observabilidad con ntopng en :3000
docker compose --profile observability up -d
```

---

## Flujo de fases

| Fase | Script de entrada | Duración estimada | Requiere coordinación |
|------|------------------|------------------|-----------------------|
| 1 — Recon | `scripts/phase-1-recon/recon.sh` | ~2 min | No |
| 2 — Scanning | `scripts/phase-2-scanning/port-scan.sh` | ~10 min | No |
| 2 — Scanning UDP | `scripts/phase-2-scanning/udp-scan.sh` | ~15 min | No |
| 2 — Service detect | `scripts/phase-2-scanning/service-detect.sh` | ~5 min | No |
| 3 — Enum HTTP | `scripts/phase-3-enumeration/enum-http.sh` | ~5 min | No |
| 3 — Enum SMB | `scripts/phase-3-enumeration/enum-smb.sh` | ~3 min | No |
| 3 — Enum SSH | `scripts/phase-3-enumeration/enum-ssh.sh` | ~1 min | No |
| 3 — Enum FTP | `scripts/phase-3-enumeration/enum-ftp.sh` | ~1 min | No |
| 4 — Default creds | `scripts/phase-4-credentials/default-creds.sh` | ~2 min | ACK Blue Team |
| 4 — Brute force | `scripts/phase-4-credentials/brute-force.sh` | ~5 min | ACK Blue Team |
| 5 — SQLi | `scripts/phase-5-exploitation/web-sqli.sh` | ~5 min | ACK Blue Team |
| 5 — Web shells | `scripts/phase-5-exploitation/web-shells.sh` | ~2 min | ACK Blue Team |
| **6 — DoS** | `scripts/phase-6-dos/run-dos-window.sh` | ~25 min | **Confirmación escrita** |
| 7 — Post-exploit | `scripts/phase-7-post-exploitation/privesc-check.sh` | ~5 min | Informar después |

Toda la evidencia se genera automáticamente en `evidence/phase-N/<timestamp>/`.

---

## Variables de entorno

| Variable | Default | Descripción |
|---|---|---|
| `LAB_TARGET` | `172.20.0.20` | IP del objetivo |
| `LAB_NETWORK` | `172.20.0.0/24` | Subred del laboratorio |
| `EVIDENCE_ROOT` | `/root/loot` | Raíz de evidencia (dentro del Kali) |
| `PAUSE_BETWEEN_VECTORS` | `300` | Segundos entre vectores DoS (reducir a 30 para pruebas) |

---

## Observabilidad

```bash
# Captura de tráfico host-side (requiere root en el host, no dentro del Kali)
sudo bash observability/start-pcap.sh
# ...ejecutar ataques...
sudo bash observability/stop-pcap.sh

# Dashboard ntopng: http://localhost:3000
docker compose --profile observability up -d
```

Ver `observability/README.md` para resolver el nombre del bridge dinámico.

---

## Reglas de seguridad operativa

1. **Toda actividad ofensiva ocurre en `lab-net` (172.20.0.0/24).** Los scripts rechazan targets fuera de esta subred automáticamente.
2. **Coordinar con Blue Team antes de fases disruptivas.** Ver `playbooks/recon-coordination.md`.
3. **Ventana DoS requiere confirmación escrita del Blue Team.** Ver `playbooks/dos-playbook.md`.
4. **Las credenciales encontradas se documentan solo en `evidence/` (gitignored)**, nunca se commitean.
5. **Capturas de pantalla deben mostrar el prompt completo y el comando ejecutado.** Ver `playbooks/evidence-format.md`.

---

## Estructura del repositorio

```
docker/          → Stack Docker (compose + Dockerfile del Kali)
scripts/         → Scripts ofensivos por fase (lib/ + phase-N/)
observability/   → Captura de tráfico y dashboard ntopng
playbooks/       → Coordinación, formatos y plantillas
evidence/        → Evidencia generada (gitignored)
reports/         → Plan_Red_Team.docx y plantillas de informe
```

---

## Smoke test de la biblioteca compartida

```bash
docker compose exec kali bash /root/scripts/lib/test-common.sh
```

Todos los tests deben pasar antes de ejecutar cualquier fase.
