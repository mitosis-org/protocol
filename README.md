# Mitosis

Mitosis is an Ecosystem-Owned Liquidity (EOL) layer1 blockchain that empowers newly created modular blockchains to capture Total Value Locked (TVL) and attract users through its governance process.

## Getting Started

### Prerequisites

- Git
- Yarn
- Solc
- Foundry (for `forge` and `cast` commands)

### Installation

1. Clone the repository and its submodules:

   ```bash
   git clone https://github.com/mitosis-org/protocol --recursive
   cd protocol
   ```

2. Install dependencies:

   ```bash
   yarn install
   ```

3. Build the project:

   ```bash
   forge build
   ```

### Account Setup

We recommend using `cast`'s keystore feature for secure key management. Store your key in the keystore with:

```bash
cast wallet import [account-name] -i
```

You can then use the `--account` flag when running scripts.

### Environment Setup

You can refer [`.env.example`](.env.example) for the environment variables needed to run the project.

Please create a `.env` file and fill in the necessary values.

Here's full list of environment variables:

- **Mainnet**

  | Network                                           | Chain ID                                                     | RPC                         | Etherscan Key                    |
  | ------------------------------------------------- | ------------------------------------------------------------ | --------------------------- | -------------------------------- |
  | MITOSIS                                           | -                                                            | `MITOSIS_MAINNET_RPC`       | `MITOSIS_MAINNET_ETHERSCAN_KEY`  |
  | [`ARBITRUM`](https://arbitrum.io/)                | [42161](https://chainlist.org/?testnets=true&search=42161)   | `ARBITRUM_MAINNET_RPC`      | `ARBITRUM_MAINNET_ETHERSCAN_KEY` |
  | [`BLAST`](https://blast.io/)                      | [81457](https://chainlist.org/?testnets=true&search=81457)   | `BLAST_MAINNET_RPC`         | `BLAST_MAINNET_ETHERSCAN_KEY`    |
  | [`ETHEREUM`](https://ethereum.org/)               | [1](https://chainlist.org/?testnets=true&search=1)           | `ETHEREUM_MAINNET_RPC`      | `ETHEREUM_MAINNET_ETHERSCAN_KEY` |
  | [`LINEA`](https://linea.build/)                   | [59144](https://chainlist.org/?testnets=true&search=59144)   | `LINEA_MAINNET_RPC`         | `LINEA_MAINNET_ETHERSCAN_KEY`    |
  | [`MANTA PACIFIC`](https://pacific.manta.network/) | [169](https://chainlist.org/?testnets=true&search=169)       | `MANTA_PACIFIC_MAINNET_RPC` | -                                |
  | [`MODE`](https://www.mode.network/)               | [34443](https://chainlist.org/?testnets=true&search=34443)   | `MODE_MAINNET_RPC`          | -                                |
  | [`OPTIMISM`](https://www.optimism.io/)            | [10](https://chainlist.org/?testnets=true&search=10)         | `OPTIMISM_MAINNET_RPC`      | `OPTIMISM_MAINNET_ETHERSCAN_KEY` |
  | [`SCROLL`](https://scroll.io/)                    | [534352](https://chainlist.org/?testnets=true&search=534352) | `SCROLL_MAINNET_RPC`        | `SCROLL_MAINNET_ETHERSCAN_KEY`   |

- **Devnet/Testnet**

  | Network                                                   | Chain ID                                                         | RPC                         | Etherscan Key                    |
  | --------------------------------------------------------- | ---------------------------------------------------------------- | --------------------------- | -------------------------------- |
  | MITOSIS                                                   | -                                                                | `MITOSIS_DEVNET_RPC`        | `MITOSIS_DEVNET_ETHERSCAN_KEY`   |
  | [`ARBITRUM SEPOLIA`](https://arbitrum.io/)                | [421614](https://chainlist.org/?testnets=true&search=421614)     | `ARBITRUM_SEPOLIA_RPC`      | `ARBITRUM_SEPOLIA_ETHERSCAN_KEY` |
  | [`BLAST SEPOLIA`](https://blast.io/)                      | [23888](https://chainlist.org/?testnets=true&search=23888)       | `BLAST_SEPOLIA_RPC`         | `BLAST_SEPOLIA_ETHERSCAN_KEY`    |
  | [`ETHEREUM SEPOLIA`](https://ethereum.org/)               | [11155111](https://chainlist.org/?testnets=true&search=11155111) | `ETHEREUM_SEPOLIA_RPC`      | `ETHEREUM_SEPOLIA_ETHERSCAN_KEY` |
  | [`LINEA SEPOLIA`](https://linea.build/)                   | [59141](https://chainlist.org/?testnets=true&search=59141)       | `LINEA_SEPOLIA_RPC`         | `LINEA_SEPOLIA_ETHERSCAN_KEY`    |
  | [`MANTA PACIFIC SEPOLIA`](https://pacific.manta.network/) | [3441006](https://chainlist.org/?testnets=true&search=3441006)   | `MANTA_PACIFIC_SEPOLIA_RPC` | -                                |
  | [`MODE SEPOLIA`](https://www.mode.network/)               | [919](https://chainlist.org/?testnets=true&search=919)           | `MODE_SEPOLIA_RPC`          | -                                |
  | [`OPTIMISM SEPOLIA`](https://www.optimism.io/)            | [11155420](https://chainlist.org/?testnets=true&search=11155420) | `OPTIMISM_SEPOLIA_RPC`      | `OPTIMISM_SEPOLIA_ETHERSCAN_KEY` |
  | [`SCROLL SEPOLIA`](https://scroll.io/)                    | [534351](https://chainlist.org/?testnets=true&search=534351)     | `SCROLL_SEPOLIA_RPC`        | `SCROLL_SEPOLIA_ETHERSCAN_KEY`   |

### Verification

To verify your setup, run the following script to display multichain balances for a given account:

```bash
forge script ./script/Multichain.s.sol \
    [--account {account-name} | --private-key {hexed-private-key} | --mnemonic {mnemonic-phrase}]
```

## Usage

[TBD]

## Contributing

[TBD]

## License

MIT

## Support

Please reach out to the following team members for support:

- @byeongsu-hong
- @taeguk
- @dbadoy
