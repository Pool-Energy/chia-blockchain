#!/bin/bash

set -e

# Update /etc/hosts in container (IPv6 removed)
grep -v "::" /etc/hosts > /tmp/tmphosts
cat /tmp/tmphosts > /etc/hosts

# Check /data volume
if [ ! -d "/data" ]; then
	echo "Error: no /data to persist"
	exit 1
fi

network=${CHIA_NETWORK:=mainnet}
chia_mode=${CHIA_MODE:=node}

cd /root/chia-blockchain
. ./activate

if [ ${chia_mode} = "wallet" ]; then

	rm -rf /root/.chia /root/.chia_keys
	if echo ${network} | grep -q testnet; then
		chia init --testnet
	else
		chia init
	fi

	# To use docker secret (require docker swarm orchestrator)
	# echo "word1 word2 word3 ..." | docker secret create wallet_keys_${WALLET_ID}
	[ -e "/run/secrets/wallet_key_${WALLET_ID:=1}" ] && WALLET_KEY_PATH="/run/secrets"
	chia keys add -l ${WALLET_ID} -f ${WALLET_KEY_PATH:=/data}/wallet_keys_${WALLET_ID:=1}

	rm -rf /root/.chia/mainnet/wallet
	mkdir -p /data/wallet_${WALLET_ID:=1}
	ln -fs /data/wallet_${WALLET_ID:=1} /root/.chia/mainnet/wallet

	if [ -f "/data/wallet_${WALLET_ID:=1}_ssl/wallet/private_wallet.key" ]; then
		rm -rf /root/.chia/mainnet/config/ssl
		ln -fs /data/wallet_${WALLET_ID:=1}_ssl /root/.chia/mainnet/config/ssl
	else
		mkdir -p /data/wallet_${WALLET_ID:=1}_ssl
		cp -a /root/.chia/mainnet/config/ssl/* /data/wallet_${WALLET_ID:=1}_ssl/
	fi

	python3 /root/update-config.py
	rm -rf /root/update-config.py

	./venv/bin/python -m chia.daemon.server &
	while ! nc -z -w 1 localhost 55400; do
		echo "waiting 55400"
		sleep 0.1
	done

	if [ -n "${CHIA_EXPORTER}" ]; then
		/root/chia-exporter/chia_exporter serve 2>&1 >/dev/null &
	fi

	if [ -n "${CHIA_STDOUT}" ]; then
		tail -F /root/.chia/mainnet/log/debug.log &
	fi

	exec ./venv/bin/chia_wallet

else

	mkdir -p /root/.chia
	ln -fs /data/chia/${network} /root/.chia/mainnet

	if echo ${network} | grep -q testnet; then
		chia init --testnet
	else
		chia init
	fi

	sed -i 's/self_hostname:.*/self_hostname: \&self_hostname 0.0.0.0/' /data/chia/${network}/config/config.yaml || true

	rm -rf /root/update-config.py

	./venv/bin/python -m chia.daemon.server &
	while ! nc -z -w 1 localhost 55400; do
		echo "waiting 55400"
		sleep 0.1
	done

	if [ -n "${CHIA_EXPORTER}" ]; then
		/root/chia-exporter/chia_exporter serve 2>&1 >/dev/null &
	fi

	if [ -n "${CHIA_STDOUT}" ]; then
		tail -F /root/.chia/mainnet/log/debug.log &
	fi

	exec ./venv/bin/chia_full_node
fi
