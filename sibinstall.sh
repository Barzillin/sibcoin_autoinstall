#!/bin/bash
#
# Copyright (C) 2020 Sibcoin Team
#
# SIBCOIN Masternode installation script, by Barzillin.
#
# Only Ubuntu 16.04 supported at this moment (tested with 18.04, working)

set -o errexit

# OS_VERSION_ID=`gawk -F= '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"'`

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef"-o Dpkg::Options::="--force-confold" upgrade
sudo apt install curl wget git python3 python3-pip virtualenv -y

SIB_DAEMON_USER_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo ""`
SIBIQ_DAEMON_RPC_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 ; echo ""`
SIBMN_NAME_PREFIX=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6 ; echo ""`
SIBMN_EXTERNAL_IP=`curl -s -4 ifconfig.co`

sudo useradd -U -m sibcoin -s /bin/bash
sudo echo "sibcoin:${SIB_DAEMON_USER_PASS}"| sudo chpasswd
sudo wget https://github.com/ivansib/sibcoin/releases/download/v0.17.0.0/sibcoin-0.17.0-x86_64-linux-gnu.tar.gz --directory-prefix /home/sibcoin/
sudo tar -xzvf /home/sibcoin/sibcoin-0.17.0-x86_64-linux-gnu.tar.gz -C /home/sibcoin/
sudo rm /home/sibcoin/sibcoin-0.17.0-x86_64-linux-gnu.tar.gz
sudo mkdir /home/sibcoin/.sibcoincore/
sudo chown -R sibcoin:sibcoin /home/sibcoin/sibcoin*
sudo chmod 755 /home/sibcoin/sibcoin*
echo -e "rpcuser=sibcoinrpc\nrpcpassword=${SIBIQ_DAEMON_RPC_PASS}\nlisten=1\nserver=1\nrpcallowip=127.0.0.1\nmaxconnections=256"  | sudo tee /home/sibcoin/.sibcoin/sibcoin.conf
sudo chown -R sibcoin:sibcoin /home/sibcoin/.sibcoincore/
sudo chown 500 /home/sibcoin/.sibcoincore/sibcoin.conf
sudo mv /home/sibcoin/sibcoin-0.17.0/bin/sibcoin-cli /home/sibcoin/
sudo mv /home/sibcoin/sibcoin-0.17.0/bin/sibcoind /home/sibcoin/

sudo tee /etc/systemd/system/sibcoin.service <<EOF
[Unit]
Description=SIBcoin, Russian Privacy Cryptocurrency
After=network.target

[Service]
User=sibcoin
Group=sibcoin
WorkingDirectory=/home/sibcoin/
ExecStart=/home/sibcoin/sibcoind

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=2s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable sibcoin
sudo systemctl start sibcoin
echo "Booting SIBCOIN node and creating wallet, please wait!"
sleep 120

echo "Now open your SIBcoin wallet, go to Console, and type "masternode genkey" and "bls generate"!"
echo "Now from local wallet paste your genkey and bls priv key!"
read MNGENKEY
read BLSGENKEY
echo -e "masternode=1\nmasternodeprivkey=${MNGENKEY}\nmasternodeblsprivkey=${BLSGENKEY}\nexternalip=${SIBMN_EXTERNAL_IP}:1945" | sudo tee -a /home/sibcoin/.sibcoin/sibcoin.conf
sudo systemctl restart sibcoin

echo "Installing sentinel engine, please standby!"
sudo gitclone https://github.com/ivansib/sentinel.git /home/sibcoin/sentinel/
sudo chown -R sibcoin:sibcoin /home/sibcoin/sentinel/
cd /home/sibcoin/sentinel/
echo -e "sibcoin_conf=/user/sibcoin/.sibcoin/sibcoin.conf" | sudo tee -a /home/sibcoin/sentinel/sentinel.conf
sudo -H -u sibcoin virtualenv -p python3 ./venv
sudo virtualenv venv
sudo ./venv/bin/pip install -r requirements.txt

echo "* * * * * cd /home/sibcoin/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" | sudo tee /etc/cron.d/sibcoin_sentinel
sudo chmod 644 /etc/cron.d/sibcoin_sentinel

echo " "
echo " "
echo "==============================="
echo "SIB v.17 Masternode installed by SIBCOIN Rux Script"
echo "==============================="
echo "Copy and keep that information in secret:"
echo "Masternode key: ${MNGENKEY}"
echo "BLS key: ${BLSGENKEY}"
echo "SSH password for user \"sibcoin\": ${SIB_DAEMON_USER_PASS}"
echo "Prepared masternode.conf string:"
echo "mn_${SIBMN_NAME_PREFIX} ${SIBMN_EXTERNAL_IP}:14014 ${MNGENKEY} INPUTTX INPUTINDEX"

exit 0
