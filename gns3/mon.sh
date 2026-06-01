#!/bin/sh
while true; do
  wget -qO- http://172.20.0.50 >/dev/null 2>&1 && echo "$(date +%T) HTTP 200" || echo "$(date +%T) HTTP 000"
  sleep 1
done
