#!/bin/bash

set -e

echo "------------------------------------------------"
echo "INICIANDO SCRIPT DE CONFIGURAÇÃO - PROVINCIA"
echo "------------------------------------------------"

ZABBIX_SERVER="192.168.40.101"
HOSTNAME_ATUAL=$(hostname)

echo "1/6 - Atualizando sistema..."
apt update && apt upgrade -y

echo "2/6 - Instalando repositório oficial do Zabbix 7.4..."
wget -q https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.4-1+ubuntu24.04_all.deb
dpkg -i zabbix-release_7.4-1+ubuntu24.04_all.deb
apt update
apt install zabbix-agent -y

echo "3/6 - Instalando pacotes de segurança e SSH..."
apt install -y openssh-server chkrootkit clamav clamav-daemon

echo "4/6 - Configurando Zabbix Agent..."
cat > /etc/zabbix/zabbix_agentd.conf << EOF
####### GENERAL PARAMETERS #################
LogFile=/var/log/zabbix/zabbix_agentd.log
Server=$ZABBIX_SERVER
ServerActive=$ZABBIX_SERVER
Hostname=$HOSTNAME_ATUAL

UserParameter=antivirus.clamav,command -v clamscan >/dev/null 2>&1 && echo "INSTALADO" || echo "AUSENTE"
UserParameter=antivirus.chkrootkit,command -v chkrootkit >/dev/null 2>&1 && echo "INSTALADO" || echo "AUSENTE"
###########################################
EOF

systemctl enable zabbix-agent
systemctl restart zabbix-agent

echo "5/6 - Criando serviços e timers de segurança..."

# Chkrootkit Service
cat > /etc/systemd/system/chkrootkit.service << EOF
[Unit]
Description=Verificação de Rootkits

[Service]
Type=oneshot
ExecStart=/usr/sbin/chkrootkit
StandardOutput=append:/var/log/chkrootkit.log
EOF

# Chkrootkit Timer
cat > /etc/systemd/system/chkrootkit.timer << EOF
[Unit]
Description=Chkrootkit diário

[Timer]
OnCalendar=*-*-* 12:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# ClamAV Scan Service
cat > /etc/systemd/system/clamavscan.service << EOF
[Unit]
Description=Scan ClamAV

[Service]
Type=oneshot
ExecStart=/usr/bin/clamscan -r /home --log=/var/log/clamscan.log --quiet
EOF

# ClamAV Scan Timer
cat > /etc/systemd/system/clamavscan.timer << EOF
[Unit]
Description=Scan ClamAV diário

[Timer]
OnCalendar=*-*-* 12:10:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "6/6 - Ativando timers..."
systemctl daemon-reload
systemctl enable --now chkrootkit.timer
systemctl enable --now clamavscan.timer
systemctl enable clamav-daemon
systemctl restart clamav-daemon

echo "------------------------------------------------"
echo "✅ PROCEDIMENTO CONCLUÍDO COM SUCESSO!"
echo "Host: $HOSTNAME_ATUAL | Zabbix Server: $ZABBIX_SERVER"
echo "------------------------------------------------"
