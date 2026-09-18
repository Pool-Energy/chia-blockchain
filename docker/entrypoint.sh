#!/bin/bash

set -e

grep -v "::" /etc/hosts > /tmp/tmphosts
cat /tmp/tmphosts > /etc/hosts

CHIA_NETWORK=${CHIA_NETWORK:=mainnet}
CHIA_MODE=${CHIA_MODE:=node}
CHIA_BASEDIR=${CHIA_BASEDIR:=/data}
CHIA_DAEMON_PORT=${CHIA_DAEMON_PORT:=55400}
CHIA_FULLNODE_PORT=${CHIA_FULLNODE_PORT:=8444}
CHIA_LOGLEVEL=${CHIA_LOGLEVEL:=INFO}
CHIA_EXPORTER=${CHIA_EXPORTER:=false}
CHIA_STDOUT=${CHIA_STDOUT:=true}

cd /root/chia-blockchain
. ./activate

echo "#########################################################################################################################"
echo ""
echo "       ██████ ██   ██ ██  █████        ██████  ██       ██████   ██████ ██   ██  ██████ ██   ██  █████  ██ ███    ██  "
echo "      ██      ██   ██ ██ ██   ██       ██   ██ ██      ██    ██ ██      ██  ██  ██      ██   ██ ██   ██ ██ ████   ██  "
echo "      ██      ███████ ██ ███████ █████ ██████  ██      ██    ██ ██      █████   ██      ███████ ███████ ██ ██ ██  ██  "
echo "      ██      ██   ██ ██ ██   ██       ██   ██ ██      ██    ██ ██      ██  ██  ██      ██   ██ ██   ██ ██ ██  ██ ██  "
echo "       ██████ ██   ██ ██ ██   ██       ██████  ███████  ██████   ██████ ██   ██  ██████ ██   ██ ██   ██ ██ ██   ████  "
echo ""
echo "#########################################################################################################################"
echo ""
echo "Using chia-blockchain:"
echo "  * version: $(git branch --show-current)"
echo "  * network: ${CHIA_NETWORK}"
echo "  * mode: ${CHIA_MODE}"
echo "  * exporter: ${CHIA_EXPORTER}"
echo "  * stdout: ${CHIA_STDOUT}"
echo "  * loglevel: $(echo ${CHIA_LOGLEVEL} | tr '[:upper:]' '[:lower:]')"
echo ""

mkdir -p /root/.chia
ln -sf ${CHIA_BASEDIR}/${CHIA_NETWORK} /root/.chia/${CHIA_NETWORK}

if [ ${CHIA_MODE} = "wallet" ]; then
	if [ $CHIA_NETWORK == *"testnet"* ]; then
		chia init --testnet
	else
		chia init
	fi

	if [ ! -e "${CHIA_BASEDIR}/config/mnemonic" ]; then
		echo "Error: No mnemonic file found: ${CHIA_BASEDIR}/config/mnemonic"
		exit 1
	else
		chia keys add -l wallet -f ${CHIA_BASEDIR}/config/mnemonic
	fi

	python3 /root/update-config.py

	./venv/bin/python -m chia.daemon.server &
	while ! nc -z -w 1 localhost ${CHIA_DAEMON_PORT}; do
		echo "Waiting port ${CHIA_DAEMON_PORT}..."
		sleep 0.1
	done

	if [ ${CHIA_EXPORTER} = "true" ]; then
		/root/chia-exporter/chia_exporter serve 2>&1 >/dev/null &
	fi

	if [ ${CHIA_STDOUT} = "true" ]; then
		tail -F /root/.chia/${CHIA_NETWORK}/log/debug.log &
	fi

	exec ./venv/bin/chia_wallet
else
	if [ ${CHIA_NETWORK} == *"testnet"* ]; then
		chia init --testnet
	else
		chia init
	fi

	sed -i "s/self_hostname:.*/self_hostname: \&self_hostname 0.0.0.0/" \
		${CHIA_BASEDIR}/${CHIA_NETWORK}/config/config.yaml \
		|| true

	sed -i "s/log_level:.*/log_level: \"${CHIA_LOGLEVEL}\"/g" \
		${CHIA_BASEDIR}/${CHIA_NETWORK}/config/config.yaml \
		|| true

	./venv/bin/python -m chia.daemon.server &
	while ! nc -z -w 1 localhost ${CHIA_DAEMON_PORT}; do
		echo "Waiting port ${CHIA_DAEMON_PORT}..."
		sleep 0.1
	done

	if [ ${CHIA_EXPORTER} = "true" ]; then
		/root/chia-exporter/chia_exporter serve 2>&1 >/dev/null &
	fi

	if [ ${CHIA_STDOUT} = "true" ]; then
		tail -F /root/.chia/${CHIA_NETWORK}/log/debug.log &
	fi

	exec ./venv/bin/chia_full_node
fi
