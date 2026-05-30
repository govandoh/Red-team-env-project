#!/bin/bash
# Verificación end-to-end ejecutada DENTRO del contenedor Kali (172.20.0.10)
echo "=== Ping sweep ==="
for ip in 172.20.0.20 172.20.0.30 172.20.0.31 172.20.0.50 172.20.0.51 172.20.0.52 172.20.0.53; do
    if ping -c1 -W2 "$ip" >/dev/null 2>&1; then echo "  $ip UP"; else echo "  $ip DOWN"; fi
done

echo ""
echo "=== Servicios Blue Team ==="
printf "  bt-web  HTTP 80    : "; curl -s -o /dev/null -w "%{http_code}\n" --max-time 4 http://172.20.0.50/
printf "  bt-dns  resolver   : "; dig +short +time=2 +tries=1 @172.20.0.51 bt-web.lab.local A 2>/dev/null | head -1
printf "  bt-smb  share list : "; timeout 5 smbclient -L //172.20.0.52 -N 2>/dev/null | awk '/Disk/{print $1}' | tr '\n' ' '; echo ""
printf "  bt-mail SMTP 25    : "; echo QUIT | timeout 5 nc -w3 172.20.0.53 25 2>/dev/null | head -1

echo ""
echo "=== Metasploitable2 (objetivo clasico) ==="
printf "  MSF2 puertos clave : "
for p in 21 22 23 80 445; do
    timeout 2 bash -c "exec 3<>/dev/tcp/172.20.0.20/$p" 2>/dev/null && printf "%s/abierto " "$p"
done
echo ""
