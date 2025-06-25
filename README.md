# Mitosis [![CI](https://github.com/mitosis-org/protocol/actions/workflows/test.yml/badge.svg)](https://github.com/mitosis-org/protocol/actions/workflows/test.yml) [![Coverage](https://codecov.io/gh/mitosis-org/protocol/graph/badge.svg?token=N10BDMQSVX)](https://codecov.io/gh/mitosis-org/protocol)

Mitosis is an Ecosystem-Owned Liquidity (EOL) blockchain that empowers newly created modular blockchains to capture Total Value Locked (TVL) and attract users through its governance process.

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

3. Install dependencies via soldeer:

   ```bash
   forge soldeer install
   ```

4. Build the project:

   ```bash
   forge build
   ```

### Documentation

```bash
forge doc --build --serve
```

## License

Apache-2.0
