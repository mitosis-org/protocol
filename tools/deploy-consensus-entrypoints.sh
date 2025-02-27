#!/usr/bin/env bash

# NOTE: This tool is not for production use. It is for development and testing purposes only.

if [ -z "${RPC_URL}" ]; then
    RPC_URL="http://127.0.0.1:8545"
fi

if [ -z "${PRIVATE_KEY}" ]; then
    # Mnemonic: end alley essay random boost student weather sibling coffee grow again brief
    # Address: 0x2FB9C04d3225b55C964f9ceA934Cc8cD6070a3fF
    PRIVATE_KEY="0x5a496832ac0d7a484e6996301a5511dbc3b723d037bc61261ecaf425bd6a5b37"
fi

forge script script/DeployConsensusEntrypoints.s.sol:DeployConsensusEntrypoints \
    --broadcast -vvvv \
    --rpc-url "${RPC_URL}" \
    --private-key "${PRIVATE_KEY}"
