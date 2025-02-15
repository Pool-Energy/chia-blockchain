#!/usr/bin/env python3

import os
import yaml


def main():
    network = os.environ.get('CHIA_NETWORK', 'mainnet')
    basedir = os.environ.get('CHIA_BASEDIR', '/data')
    loglevel = os.environ.get('CHIA_LOGLEVEL', 'INFO')
    node_host = os.environ.get('CHIA_NODE_HOST', 'chia-blockchain')
    node_port = os.environ.get('CHIA_NODE_PORT', 8444)
    target_peer_count = os.environ.get('CHIA_TARGET_PEER_COUNT', 3)
    initial_num_public_keys = os.environ.get('CHIA_INITIAL_NUM_PUBLIC_KEYS', 1001)
    trusted_node_id = os.environ.get('CHIA_TRUSTED_NODE_ID', 'trusted_node_id')
    trusted_node_ssl = os.environ.get('CHIA_TRUSTED_NODE_SSL', f'{basedir}/chia/{network}/config/ssl/full_node/public_full_node.crt')

    with open(f'/root/.chia/{network}/config/config.yaml', 'r') as f:
        config = yaml.safe_load(f)

    config['self_hostname'] = '0.0.0.0'
    config['farmer']['logging']['log_level'] = loglevel
    config['wallet']['initial_num_public_keys'] = int(initial_num_public_keys)
    config['wallet']['target_peer_count'] = int(target_peer_count)
    config['wallet']['trusted_peers'][trusted_node_id] = trusted_node_ssl

    if node_host:
        config['wallet']['full_node_peers'][0]['host'] = node_host
        config['wallet']['full_node_peers'][0]['port'] = int(node_port)
    else:
        config['wallet'].pop('full_node_peer', None)

    for k, v in os.environ.items():
        if not k.startswith('CHIA_WALLET_'):
            continue

        suffix = len('CHIA_WALLET_')
        name = k[suffix:].lower()

        if v.isdigit():
            v = int(v)
        elif v in ('true', 'false'):
            v = bool(v)

        config['wallet'][name] = v

    with open(f'/root/.chia/{network}/config/config.yaml', 'w') as f:
        yaml.dump(config, f)


if __name__ == '__main__':
    main()
