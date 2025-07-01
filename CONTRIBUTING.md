# Contributing to Mitosis Protocol

Thank you for contributing to Mitosis Protocol. Please follow these guidelines carefully.

## Prerequisites

- **Git** - Version control
- **Node.js** and **Yarn** - Package management and tooling
- **Foundry** - Smart contract development framework
- **Solc** - Solidity compiler

Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Setup

1. **Clone and Install**

   ```bash
   git clone https://github.com/YOUR_USERNAME/protocol --recursive
   cd protocol
   yarn install
   forge soldeer install
   ```

2. **Build and Test**
   ```bash
   forge build
   forge test
   ```

## Coding Standards

### Core Principles

- **KISS**: Prefer simple, elegant solutions
- **DRY**: Avoid code duplication; check existing codebase first
- **YAGNI**: Only add functionality when explicitly needed
- **SOLID**: Apply single responsibility, dependency inversion principles
- **File Size**: Keep files under 200-300 lines; refactor proactively

### Solidity Guidelines

**Follow these mandatory patterns:**

- Follow Coinbase style guide
- Use **ERC7201** (namespaced storage) pattern with separate abstract storage contracts
- Use **UUPS Proxy** (except extraordinary cases like beacon proxy)
- Use **ReentrancyGuardTransient** only when necessary
- **Must use** OpenZeppelin's SafeERC20 or Solady's SafeTransferLib for all token transfers

## Testing

### Commands

```bash
# Run tests
forge test

# Run with verbosity
forge test -vvv

# Coverage report
forge coverage

# Gas analysis
forge test --gas-report
```

## Pull Request Process

1. Open an issue
   - If the issue is security-related, please check the [SECURITY.md](SECURITY.md) section.
2. Create a new branch from main
3. Follow the PR template
4. Ensure all tests pass
5. Update documentation as needed
6. Get at least one review before merging

---

**Remember**: This project handles sensitive financial protocols. Security and code quality are paramount.
