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

## Technical Stack

- **Contracts**: Solidity, Foundry, Soldeer
- **Scripting**: TypeScript, Yarn
- **Package Management**: Soldeer + Yarn (via `forge soldeer` command)

⚠️ **Important**: Always check `foundry.toml` for remappings configuration before working with contract imports.

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

### Security Requirements
- This project is **extremely sensitive** to security vulnerabilities
- **Never** mock data for dev or prod environments (only for tests)
- **Never** introduce new patterns/technologies unless existing options are exhausted
- **Never** overwrite `.env` files without explicit confirmation

## Development Workflow

### Task Execution
- Focus **only** on code relevant to your task
- Break complex tasks into logical stages with confirmation checkpoints
- For simple tasks: implement fully; for complex tasks: use review checkpoints

### Planning Process
1. **Large Changes**: Create `plan.md` with implementation steps and wait for approval
2. **Progress Tracking**: Update `progress.md` after each component completion
3. **Next Steps**: Update `TODO.txt` with pending tasks

### Change Classification
- **Small**: Minor changes (bug fixes, small improvements)
- **Medium**: Moderate changes (feature additions, refactoring)
- **Large**: Significant changes (architecture changes, major features)

## Testing

### Requirements
- Write thorough tests for all major functionality
- Include edge case tests
- Maintain or improve test coverage
- Test all security-critical functions

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

## Security Reviews

When reviewing smart contracts:
- Review with **strong responsibility**
- Reference `slither-detectors.mdc` for static analysis
- Read corresponding interface files (e.g., `GovMITO.sol` → `IGovMITO.sol`)
- **Read entire files** - don't miss anything
- Create detailed reports in severity order with suggestions
- Detect unused variables, functions, and imports
- Review from **system design perspective** and suggest improvements
- Use random emojis (✅,✨) for lines with no issues

## Pull Request Process

1. **Before Submitting**
   - Ensure code compiles without warnings
   - Run full test suite
   - Check that coverage doesn't decrease
   - Follow all coding standards

2. **PR Requirements**
   - Clear description with motivation
   - Testing methodology explained
   - List any breaking changes
   - Link related issues

3. **Review Process**
   - All CI checks must pass
   - Security-sensitive changes require additional review
   - At least one maintainer approval required

## Communication

- Provide brief summaries after completing components
- Ask clarifying questions when uncertain about scope
- Track completed vs. pending features in responses
- Respond with appropriate urgency for critical issues

## Documentation

- Generate brief markdown docs in `/docs/[feature].md` for major features
- Update `/docs/overview.md` accordingly
- Include comprehensive code comments and NatSpec documentation

---

**Remember**: This project handles sensitive financial protocols. Security and code quality are paramount. 