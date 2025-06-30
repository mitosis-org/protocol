# protocol 

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![CI](https://github.com/mitosis-org/protocol/actions/workflows/test.yml/badge.svg)](https://github.com/mitosis-org/protocol/actions/workflows/test.yml) 
[![codecov](https://codecov.io/gh/mitosis-org/protocol/branch/main/graph/badge.svg?token=N10BDMQSVX)](https://codecov.io/gh/mitosis-org/protocol)

**Next-generation DeFi network enabling programmable liquidity across multiple protocols**

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

### Contributing

If you want to contribute, or follow along with contributor discussion, you can use our GitHub discussions and issues.

- Our contributor guidelines can be found in [CONTRIBUTING.md](CONTRIBUTING.md).
- See our [Security Policy](SECURITY.md) for security-related contributions.

## Getting Help

If you have any questions:

- Open a discussion with your question, or
- Open an issue with the bug
- Check our documentation at [docs.mitosis.org](https://docs.mitosis.org)

## Security

See [SECURITY.md](SECURITY.md).


## License
This project is licensed under the Apache License 2.0.
See the [LICENSE](LICENSE) file for details.
