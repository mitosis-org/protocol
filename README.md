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
