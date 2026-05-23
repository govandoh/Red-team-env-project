# INFORME FINAL — RED TEAM
## Simulación de Ataque y Defensa en Redes
### Redes 2 · Sección Sábados · Ciclo 2026

**Fecha de entrega:** 23 de mayo de 2026
**Clasificación:** Confidencial — uso académico

---

## Integrantes del equipo Red Team

| Nombre completo | Carné | Rol en el equipo |
|---|---|---|
| _________________________ | __________ | _________________________ |
| _________________________ | __________ | _________________________ |
| _________________________ | __________ | _________________________ |
| _________________________ | __________ | _________________________ |
| _________________________ | __________ | _________________________ |

---

## 1. Resumen Ejecutivo

> Completar con máximo 3 párrafos: qué se hizo, qué se encontró y cuál fue el impacto global.

Durante el ejercicio de simulación se ejecutó un ciclo completo de ataque ofensivo sobre la infraestructura objetivo proporcionada por el equipo Blue Team. El equipo Red Team aplicó la metodología PTES simplificada (Reconocimiento → Escaneo → Enumeración → Credenciales → Explotación → DoS → Post-explotación) dentro de la red aislada `lab-net (172.20.0.0/24)`.

**Hallazgos críticos identificados:**

- [PLACEHOLDER — ej. "Acceso root obtenido vía credenciales por defecto en SSH"]
- [PLACEHOLDER — ej. "Backdoor vsftpd 2.3.4 explotado exitosamente (CVE-2011-2523)"]
- [PLACEHOLDER — ej. "Servicio HTTP degradado durante 60 s con vector Slowloris"]

**Impacto global:** [PLACEHOLDER — Alto / Medio / Bajo] — justificación: _________________________.

---

## 2. Objetivos del ejercicio

### 2.1 Objetivos generales

- Identificar vulnerabilidades en la infraestructura objetivo mediante técnicas ofensivas controladas.
- Documentar evidencia técnica reproducible de cada hallazgo.
- Demostrar impacto real en la disponibilidad, integridad y confidencialidad de los servicios.

### 2.2 Objetivos específicos

| # | Objetivo | Alcanzado |
|---|---|---|
| 1 | Mapear todos los hosts y servicios activos en `172.20.0.0/24` | [ Sí / No ] |
| 2 | Identificar al menos 3 vulnerabilidades explotables | [ Sí / No ] |
| 3 | Obtener acceso autenticado a al menos 1 servicio mediante credenciales débiles | [ Sí / No ] |
| 4 | Ejecutar al menos 1 exploit funcional contra un servicio vulnerable | [ Sí / No ] |
| 5 | Demostrar degradación de servicio mediante ataque DoS coordinado | [ Sí / No ] |
| 6 | Ejecutar enumeración post-explotación con LinPEAS en shell obtenida | [ Sí / No ] |

---

## 3. Metodología

El equipo adoptó el estándar **PTES (Penetration Testing Execution Standard)** en su versión simplificada para entornos académicos. Las 7 fases se ejecutaron de forma secuencial con evidencia capturada en cada una.

| Fase | Nombre | Herramientas principales | Script |
|---|---|---|---|
| 1 | Reconocimiento | nmap, netcat, dig | `phase-1-recon/recon.sh` |
| 2 | Escaneo de puertos | nmap (-sS -sV -O), NSE vuln | `phase-2-scanning/port-scan.sh` |
| 3 | Enumeración | nikto, gobuster, enum4linux, whatweb | `phase-3-enumeration/` |
| 4 | Credenciales | hydra, credenciales por defecto manuales | `phase-4-credentials/` |
| 5 | Explotación | sqlmap, Metasploit, web-shells | `phase-5-exploitation/` |
| 6 | DoS coordinado | slowhttptest, Apache Bench, hping3 | `phase-6-dos/` |
| 7 | Post-explotación | LinPEAS, SSH | `phase-7-post-exploitation/` |

### 3.1 Reglas de enfrentamiento

- Toda actividad ofensiva ocurrió exclusivamente dentro de `172.20.0.0/24`.
- El equipo Blue Team fue notificado por escrito antes de cada fase disruptiva (fase 6).
- Duración máxima por vector DoS: 60–120 segundos.
- Ninguna credencial descubierta fue commitada al repositorio.

---

## 4. Topología del laboratorio

```
                         ┌─────────────────────────────────┐
                         │   Docker bridge: lab-net         │
                         │   Subred: 172.20.0.0/24          │
                         └───────────────┬─────────────────┘
                                         │
              ┌──────────────────────────┼──────────────────────────┐
              │                          │                          │
   ┌──────────┴──────────┐  ┌───────────┴──────────┐  ┌───────────┴──────────┐
   │   redteam-kali       │  │  blueteam-target      │  │  blueteam-client-1   │
   │   Kali Linux Rolling │  │  Metasploitable2      │  │  Ubuntu 22.04        │
   │   IP: 172.20.0.10    │  │  IP: 172.20.0.20      │  │  IP: 172.20.0.30     │
   │   Rol: ATACANTE      │  │  Rol: OBJETIVO        │  │  Rol: cliente        │
   └─────────────────────┘  └───────────────────────┘  └──────────────────────┘
```

### 4.1 Servicios expuestos por el objetivo (Metasploitable2)

| Puerto | Protocolo | Servicio | Versión | Severidad |
|---|---|---|---|---|
| 21 | TCP | FTP | vsftpd 2.3.4 | Crítica (CVE-2011-2523) |
| 22 | TCP | SSH | OpenSSH 4.7p1 | Alta (algoritmos legacy) |
| 23 | TCP | Telnet | Linux telnetd | Alta |
| 80 | TCP | HTTP | Apache 2.2.8 | Media |
| 139/445 | TCP | SMB | Samba 3.x | Alta |
| 3306 | TCP | MySQL | 5.0.51a | Alta (root sin clave) |
| 5432 | TCP | PostgreSQL | 8.3.0 | Alta (postgres:postgres) |
| 5900 | TCP | VNC | — | Alta |

---

## 5. Vulnerabilidades encontradas

> Una fila por vulnerabilidad. Completar con los hallazgos reales del escaneo.

| ID | Vulnerabilidad | Servicio | Puerto | CVE / Ref | Severidad | Evidencia |
|---|---|---|---|---|---|---|
| V-01 | [PLACEHOLDER] | [servicio] | [puerto] | [CVE o N/A] | [Crítica/Alta/Media/Baja] | `evidence/phase-2/<ts>/` |
| V-02 | [PLACEHOLDER] | [servicio] | [puerto] | [CVE o N/A] | [Crítica/Alta/Media/Baja] | `evidence/phase-2/<ts>/` |
| V-03 | [PLACEHOLDER] | [servicio] | [puerto] | [CVE o N/A] | [Crítica/Alta/Media/Baja] | `evidence/phase-3/<ts>/` |
| V-04 | [PLACEHOLDER] | [servicio] | [puerto] | [CVE o N/A] | [Crítica/Alta/Media/Baja] | `evidence/phase-4/<ts>/` |
| V-05 | [PLACEHOLDER] | [servicio] | [puerto] | [CVE o N/A] | [Crítica/Alta/Media/Baja] | `evidence/phase-5/<ts>/` |

### 5.1 Mapa de riesgo

| Severidad | Cantidad | % del total |
|---|---|---|
| Crítica | [N] | [%] |
| Alta | [N] | [%] |
| Media | [N] | [%] |
| Baja | [N] | [%] |
| **Total** | **[N]** | **100%** |

---

## 6. Evidencia de ataques ejecutados

> Por cada fase: pegar salida de terminal clave + indicar ruta de evidencia completa.

### 6.1 Fase 1 — Reconocimiento

**Comando ejecutado:**
```
bash /root/scripts/phase-1-recon/recon.sh
```

**Resultado clave:** [PLACEHOLDER — hosts descubiertos, puertos abiertos en sweep]

**Ruta de evidencia:** `evidence/phase-1-recon/<timestamp>/`

**Archivos generados:**
- `ping-sweep.txt` — [PLACEHOLDER: N hosts activos encontrados]
- `banners.txt` — [PLACEHOLDER: banners capturados]
- `run.log` — log completo de ejecución

---

### 6.2 Fase 2 — Escaneo de puertos

**Comando ejecutado:**
```
bash /root/scripts/phase-2-scanning/port-scan.sh
```

**Resultado clave:** [PLACEHOLDER — lista de puertos abiertos y versiones detectadas]

**Ruta de evidencia:** `evidence/phase-2-scanning/<timestamp>/`

**Archivos generados:**
- `full-scan.nmap` — escaneo completo TCP
- `open-ports.txt` — resumen de puertos abiertos
- `vuln-scripts.txt` — resultados NSE de vulnerabilidades

---

### 6.3 Fase 3 — Enumeración

**Comandos ejecutados:**
```
bash /root/scripts/phase-3-enumeration/enum-http.sh
bash /root/scripts/phase-3-enumeration/enum-smb.sh
bash /root/scripts/phase-3-enumeration/enum-ftp.sh
bash /root/scripts/phase-3-enumeration/enum-ssh.sh
```

**Resultado clave HTTP:** [PLACEHOLDER — directorios descubiertos, tecnologías identificadas]
**Resultado clave SMB:** [PLACEHOLDER — shares encontrados, usuarios enumerados]
**Resultado clave FTP:** [PLACEHOLDER — login anónimo exitoso/fallido]

**Ruta de evidencia:** `evidence/phase-3-enumeration/<timestamp>/`

---

### 6.4 Fase 4 — Credenciales

**Comandos ejecutados:**
```
bash /root/scripts/phase-4-credentials/default-creds.sh
bash /root/scripts/phase-4-credentials/brute-force.sh
```

**Credenciales encontradas:**

| Servicio | Usuario | Password | Método |
|---|---|---|---|
| SSH | [PLACEHOLDER] | [PLACEHOLDER] | default-creds / hydra |
| MySQL | [PLACEHOLDER] | [PLACEHOLDER] | default-creds |
| PostgreSQL | [PLACEHOLDER] | [PLACEHOLDER] | default-creds |

**Ruta de evidencia:** `evidence/phase-4-credentials/<timestamp>/`

---

### 6.5 Fase 5 — Explotación

**Comandos ejecutados:**
```
bash /root/scripts/phase-5-exploitation/web-sqli.sh
bash /root/scripts/phase-5-exploitation/msf-exploit.sh
bash /root/scripts/phase-5-exploitation/web-shells.sh
```

**Resultado SQLi:** [PLACEHOLDER — tablas encontradas, datos extraídos]
**Resultado MSF (vsftpd backdoor):** [PLACEHOLDER — shell obtenida, id, uname]
**Resultado web-shells:** [PLACEHOLDER — upload exitoso/fallido, LFI encontrado]

**Ruta de evidencia:** `evidence/phase-5-exploitation/<timestamp>/`

---

### 6.6 Fase 6 — DoS

**Operador responsable:** _________________________
**Ventana de ataque acordada:** __________ a __________ horas
**Blue Team notificado por:** [escrito / Slack / verbal]

| Vector | Duración real | Latencia base (ms) | Latencia pico (ms) | Servicio caído | Recuperación |
|---|---|---|---|---|---|
| Slowloris | [N] s | [N] | [N] | [Sí/No/Degradado] | [N] s |
| HTTP flood | [N] s | [N] | [N] | [Sí/No/Degradado] | [N] s |
| SYN flood | [N] s | [N] | [N] | [Sí/No/Degradado] | [N] s |

**Ruta de evidencia:** `evidence/phase-6-dos/<timestamp>/`

---

### 6.7 Fase 7 — Post-explotación

**Comando ejecutado:**
```
bash /root/scripts/phase-7-post-exploitation/privesc-check.sh
```

**Shell de acceso:** [PLACEHOLDER — tipo: SSH / MSF / web-shell]
**Usuario inicial:** [PLACEHOLDER]
**Escalada de privilegios:** [PLACEHOLDER — vector encontrado por LinPEAS]
**Usuario final:** [PLACEHOLDER]

**Ruta de evidencia:** `evidence/phase-7-post-exploitation/<timestamp>/`

---

## 7. Descripción de técnicas utilizadas

| Técnica | Fase | Descripción breve | Herramienta | Referencia MITRE |
|---|---|---|---|---|
| Ping sweep | 1 | Descubrimiento de hosts activos en la subred | nmap -sn | T1018 |
| Banner grabbing | 1 | Obtención de versiones de servicios via netcat | nc | T1046 |
| Port scanning (SYN) | 2 | Escaneo sigiloso de todos los puertos TCP | nmap -sS | T1046 |
| Service version detection | 2 | Identificación de versiones y OS | nmap -sV -O | T1046 |
| Vulnerability scanning | 2 | Scripts NSE para detección automática | nmap --script vuln | T1595 |
| Web enumeration | 3 | Descubrimiento de directorios y tecnologías | nikto, gobuster | T1083 |
| SMB enumeration | 3 | Usuarios, shares y políticas de dominio | enum4linux | T1135 |
| Default credentials | 4 | Prueba de credenciales conocidas por defecto | manual | T1078.001 |
| Brute force | 4 | Ataque de diccionario sobre SSH | hydra | T1110.001 |
| SQL injection | 5 | Extracción de datos de base de datos | sqlmap | T1190 |
| Exploit CVE-2011-2523 | 5 | Backdoor vsftpd 2.3.4 | Metasploit | T1190 |
| Slowloris | 6 | Agotamiento de workers HTTP | slowhttptest | T1499.001 |
| HTTP flood | 6 | Saturación de servidor web | Apache Bench | T1498 |
| SYN flood | 6 | Agotamiento de estado TCP en el kernel | hping3 | T1498.001 |
| LinPEAS | 7 | Enumeración automática de escalada de privilegios | linpeas.sh | T1069 |

---

## 8. Impacto logrado y conclusiones

### 8.1 Impacto en CIA (Confidencialidad, Integridad, Disponibilidad)

| Dimensión | Impacto | Descripción |
|---|---|---|
| Confidencialidad | [Alto/Medio/Bajo] | [PLACEHOLDER — datos accedidos, credenciales obtenidas] |
| Integridad | [Alto/Medio/Bajo] | [PLACEHOLDER — archivos modificados, shells instaladas] |
| Disponibilidad | [Alto/Medio/Bajo] | [PLACEHOLDER — tiempo de degradación, vectores DoS] |

### 8.2 Resumen de accesos obtenidos

| Sistema | Puerto/Servicio | Nivel de acceso | Credencial / Vector |
|---|---|---|---|
| Metasploitable2 | [puerto] | [user/root] | [credencial o exploit] |
| Metasploitable2 | [puerto] | [user/root] | [credencial o exploit] |

### 8.3 Lecciones aprendidas

> Completar con mínimo 3 observaciones del equipo.

1. [PLACEHOLDER — ej. "Las credenciales por defecto representaron el vector de acceso más inmediato"]
2. [PLACEHOLDER — ej. "El backdoor de vsftpd es detectable por IDS con firma simple"]
3. [PLACEHOLDER — ej. "El SYN flood fue el vector DoS más disruptivo, tardó N segundos en recuperarse"]

### 8.4 Recomendaciones al Blue Team

| # | Recomendación | Vulnerabilidad que mitiga | Prioridad |
|---|---|---|---|
| R-01 | [PLACEHOLDER] | [V-XX] | [Alta/Media/Baja] |
| R-02 | [PLACEHOLDER] | [V-XX] | [Alta/Media/Baja] |
| R-03 | [PLACEHOLDER] | [V-XX] | [Alta/Media/Baja] |
| R-04 | [PLACEHOLDER] | [V-XX] | [Alta/Media/Baja] |

### 8.5 Conclusión final

[PLACEHOLDER — párrafo de cierre: objetivos cumplidos, nivel de riesgo de la infraestructura evaluada, valor del ejercicio para el equipo]

---

## Anexo A — Bitácora DoS

> Completar una tabla por cada vector ejecutado.

```
Vector:                   [ Slowloris | HTTP flood | SYN flood ]
Operador:                 ___________________________
Hora inicio (HH:MM:SS):   ___________________________
Hora fin (HH:MM:SS):      ___________________________
Duración real (segundos): ___________________________
Comando exacto:           ___________________________
Latencia base (ms):       ___________________________
Latencia pico (ms):       ___________________________
Códigos HTTP observados:  ___________________________
Servicio caído:           [ Sí | No | Degradado ]
Tiempo de recuperación:   ___________________________
Detección por Blue Team:  [ Sí | No | Parcial ]
Notas adicionales:        ___________________________
```

---

## Anexo B — Índice de evidencias

| Fase | Directorio | Archivos clave | Hash SHA256 (zip) |
|---|---|---|---|
| 1 — Recon | `evidence/phase-1-recon/<ts>/` | ping-sweep.txt, banners.txt | [PLACEHOLDER] |
| 2 — Scanning | `evidence/phase-2-scanning/<ts>/` | full-scan.nmap, open-ports.txt | [PLACEHOLDER] |
| 3 — Enum | `evidence/phase-3-enumeration/<ts>/` | nikto.txt, gobuster.txt | [PLACEHOLDER] |
| 4 — Creds | `evidence/phase-4-credentials/<ts>/` | hydra-results.txt | [PLACEHOLDER] |
| 5 — Exploit | `evidence/phase-5-exploitation/<ts>/` | sqli-output/, msf-shell.txt | [PLACEHOLDER] |
| 6 — DoS | `evidence/phase-6-dos/<ts>/` | *.pcap, *-ab.txt, monitor-*.csv | [PLACEHOLDER] |
| 7 — Post | `evidence/phase-7-post-exploitation/<ts>/` | linpeas-output.txt | [PLACEHOLDER] |

---

*Documento generado a partir de `reports/INFORME_FINAL_template.md` — Red Team Lab · Redes 2 · 2026*
