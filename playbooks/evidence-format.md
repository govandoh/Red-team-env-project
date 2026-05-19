# Estándar de evidencia — Red Team Lab

## Estructura de directorios

Cada script genera su propia carpeta con timestamp:

```
evidence/
└── phase-N-nombre/
    └── YYYYMMDD-HHMMSS/
        ├── run.log          ← log estructurado automático (generado por common.sh)
        ├── notes.md         ← notas humanas (llenar manualmente)
        └── <archivos del tool>
```

## `notes.md` — notas humanas por run

Crear manualmente después de cada fase con este esquema mínimo:

```markdown
# Notas — Phase N — YYYY-MM-DD HH:MM

## Observaciones
- 

## Hallazgos destacados
- 

## Anomalías o comportamientos inesperados
- 

## Próximos pasos sugeridos
- 
```

## Requisitos de screenshots

Para screenshots que vayan al informe final:
- La terminal debe mostrar el **prompt completo** (usuario, hostname, directorio)
- El **timestamp del shell** debe ser visible (o aparecer en el output del script)
- El **comando ejecutado** debe verse completo en pantalla
- El **output relevante** debe estar visible sin necesidad de scroll

**Mal ejemplo:** captura solo del output, sin ver qué comando lo generó.  
**Buen ejemplo:** captura desde el comando hasta el final del output, con prompt visible.

## Compresión para adjuntar al informe

Para generar un zip de evidencia de una fase:

```bash
# Dentro del contenedor Kali o en el host
tar -czf evidence-phase-N-$(date +%Y%m%d).tar.gz evidence/phase-N/
```

El archivo resultante está excluido del repo (`.gitignore`) — adjuntar manualmente al informe.

## Datos que NUNCA van al repo

- Contraseñas encontradas (documentar en `notes.md` local solamente)
- Pcaps completos (pueden contener información sensible)
- Archivos `.env`
- Output de hydra con credenciales en texto claro

Si se descubren credenciales válidas, anotar solo en `evidence/phase-4/<ts>/notes.md` (que está gitignored).
