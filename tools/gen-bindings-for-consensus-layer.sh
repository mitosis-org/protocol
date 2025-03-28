#!/usr/bin/env bash

gen() {
  target=$1

  # e.g., ConsensusGovernanceEntrypoint
  name=$(echo ${target} | cut -d ":" -f 2)
  
  # e.g., consensus_governance_entrypoint
  file_name=$(echo ${name} | sed 's/\([A-Z]\)/_\1/g' | sed 's/^_//' | tr '[:upper:]' '[:lower:]')

  tmp=$(mktemp -d)
  abifile=${tmp}/${name}.abi

  forge inspect ${target} abi > ${abifile}

  abigen \
    --abi ${abifile} \
    --type ${name} \
    --pkg bindings \
    --out ./bindings/${file_name}.go
}

TARGETS=(
    "src/hub/consensus-layer/ConsensusGovernanceEntrypoint.sol:ConsensusGovernanceEntrypoint"
    "src/hub/consensus-layer/ConsensusValidatorEntrypoint.sol:ConsensusValidatorEntrypoint"
)

rm -rf ./bindings && mkdir -p ./bindings

for target in "${TARGETS[@]}"; do
  gen ${target}
done
