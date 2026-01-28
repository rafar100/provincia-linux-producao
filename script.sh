#!/bin/bash

echo "------------------------------------------------"
echo "INICIANDO SCRIPT DE CONFIGURAÇÃO - PROVINCIA"
echo "------------------------------------------------"

echo "1/7 - Atualizando repositórios e sistema..."
sudo apt update && sudo apt upgrade -y

echo "2/7 - Instalando Zabbix Agent (v7.4)..."
if ! sudo apt install zabbix-agent -y; then
    echo "Aviso: Repositório padrão falhou. Baixando .deb oficial..."
    wget -q https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.4-1+ubuntu24.04_all.deb
    sudo dpkg -i zabbix-release_7.4-1+ubuntu24.04_all.deb
    sudo apt update
    sudo apt install zabbix-agent -y
fi

echo "3/7 - Configurando Hostname automático e Zabbix Conf..."
HOSTNAME_ATUAL=$(hostname)
sudo bash -c "cat > /etc/zabbix/zabbix_agentd.conf << EOF
####### GENERAL PARAMETERS #################
LogFile=/tmp/zabbix_agentd.log
Server=192.168.40.101
ServerActive=192.168.40.101
Hostname=$HOSTNAME_ATUAL
UserParameter=antivirus.clamav,if command -v clamscan >/dev/null 2>&1; then echo \"ClamAV instalado\"; else echo \"ClamAV ausente\"; fi
UserParameter=antivirus.chkrootkit,if command -v chkrootkit >/dev/null 2>&1; then echo \"chkrootkit instalado\"; else echo \"chkrootkit ausente\"; fi
############ GENERAL PARAMETERS ###########
EOF"

echo "4/7 - Instalando SSH, Chkrootkit e ClamAV..."
sudo apt install openssh-server chkrootkit clamav clamav-daemon -y

echo "5/7 - Criando serviços e Timers do Systemd..."
# Chkrootkit Service/Timer
sudo bash -c "cat > /etc/systemd/system/chkrootkit.service << EOF
[Unit]
Description=Verificação de Rootkits
After=network.target

[Service]
ExecStart=/usr/sbin/chkrootkit
StandardOutput=null
EOF"

sudo bash -c "cat > /etc/systemd/system/chkrootkit.timer << EOF
[Unit]
Description=Rodar chkrootkit ao meio-dia

[Timer]
OnCalendar=08:30
Persistent=true

[Install]
WantedBy=timers.target
EOF"

# ClamAV Timer
sudo bash -c "cat > /etc/systemd/system/clamavscan.timer << EOF
[Unit]
Description=Rodar ClamAV ao meio-dia

[Timer]
OnCalendar=12:05
Persistent=true

[Install]
WantedBy=timers.target
EOF"

echo "6/7 - Habilitando serviços..."
sudo systemctl daemon-reload
sudo systemctl enable --now chkrootkit.timer
sudo systemctl enable --now clamavscan.timer

echo "7/7 - Configurando tarefas no Cron..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/sbin/chkrootkit > /var/log/chkrootkit.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/freshclam > /var/log/freshclam.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "5 12 * * * /usr/bin/clamscan -r --quiet --log=/var/log/clamscan.log --remove /home") | crontab -
(crontab -l 2>/dev/null; echo "0 11 * * * rm -rf ~/.cache/mozilla/firefox/*.default-release/cache2/* && rm -rf ~/Downloads/*") | crontab -
(crontab -l 2>/dev/null; echo "30 11 * * * sudo apt update -y && sudo apt upgrade -y") | crontab -

echo "------------------------------------------------"
echo "✅ PROCEDIMENTO CONCLUÍDO COM SUCESSO!"
echo "PC: $HOSTNAME_ATUAL | IP Server: 192.168.40.101"
echo "------------------------------------------------"