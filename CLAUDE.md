# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Aerodrome protocol - a next-generation AMM (Automated Market Maker) inspired by Solidly, designed for EVMs. It's a complete DeFi protocol featuring:

- **Dual AMM System**: Supports both volatile (constant product) and stable (curve-based) pools
- **veTokenomics**: Time-locked voting escrow NFTs with decaying voting power
- **Managed NFTs**: Professional delegation system for veNFT management  
- **Gauge System**: Emission-based liquidity mining with user voting
- **Governance**: Multi-tiered governance with protocol and epoch governors

## Development Commands

### Building and Testing
```bash
# Install dependencies
forge install

# Build contracts
forge build

# Run all tests
forge test

# Run tests with verbose output
forge test -vvv

# Run specific test file
forge test --match-contract TestContractName

# Run tests for specific function
forge test --match-test testFunctionName

# Fork tests against Base mainnet (requires BASE_RPC_URL in .env)
forge test --fork-url $BASE_RPC_URL

# Run tests with gas reporting
forge test --gas-report
```

### Code Quality
```bash
# Format Solidity and TypeScript files
yarn format

# Check formatting without changes
yarn format:check

# Lint Solidity files (fix automatically)
yarn lint

# Check linting without fixes
yarn lint:check
```

### Deployment
```bash
# Deploy core protocol (requires .env setup)
forge script script/DeployCore.s.sol:DeployCore --broadcast --slow --rpc-url base --verify -vvvv

# Deploy gauges and pools
forge script script/DeployGaugesAndPools.s.sol:DeployGaugesAndPools --broadcast --slow --rpc-url base --verify -vvvv

# Deploy governors
forge script script/DeployGovernors.s.sol:DeployGovernors --broadcast --slow --rpc-url base --verify -vvvv
```

## Architecture Overview

### Core Token System
- **Aero.sol**: ERC-20 token with minter-controlled issuance
- **VotingEscrow.sol**: ERC-721 veNFTs with time-locked voting power that decays linearly
- **Minter.sol**: Controls token emissions with growth/decay phases and tail emissions

### AMM System  
- **Pool.sol**: Dual-mode AMM supporting both volatile (x*y=k) and stable (x³y+y³x=k) curves
- **Router.sol**: Multi-hop routing, zapping, and liquidity management
- **PoolFactory.sol**: Creates and manages pools with custom fees

### Governance & Incentives
- **Voter.sol**: Manages veNFT votes, gauge creation, and emission distribution
- **Gauge.sol**: Distributes emissions to LP stakers based on vote weights
- **RewardsDistributor.sol**: Handles rebases for locked veNFTs

### Key Factories
- **FactoryRegistry.sol**: Registry of approved factories for pools, gauges, and rewards
- **GaugeFactory.sol**: Creates gauges for pools
- **VotingRewardsFactory.sol**: Creates fee and bribe reward contracts

## Important Patterns

### Deployment Types
The codebase supports multiple deployment types via the `Deployment` enum in `Base.sol`:
- `FORK`: For mainnet fork testing
- `CUSTOM`: For custom test setups  
- `DEFAULT`: For standard testing

Inherit from `BaseTest` and set `deploymentType = Deployment.FORK` for mainnet fork tests.

### veNFT States
veNFTs exist in three states with different capabilities:
- **NORMAL**: Standard user NFTs with full functionality
- **LOCKED**: NFTs deposited into managed NFTs (restricted functionality)
- **MANAGED**: Professional manager NFTs that can accept deposits

### Time-Based Logic
The protocol uses epoch-based timing (weekly epochs starting Thursday 00:00 UTC):
- Voting restricted to specific time windows within epochs
- Emissions distributed at epoch boundaries
- Use `ProtocolTimeLibrary` for epoch calculations

### Pool Types
Two AMM formulas supported:
- **Volatile**: Standard constant product (x*y=k) for uncorrelated assets
- **Stable**: Curve formula (x³y+y³x=k) for correlated assets (stablecoins, LSTs)

## Testing Framework

### Base Test Classes
- **BaseTest.sol**: Main testing base class with common setup
- **Base.sol**: Core protocol deployment logic
- **ExtendedBaseTest.sol**: Extended setup for complex e2e tests

### Test Constants
```solidity
uint256 constant TOKEN_1 = 1e18;
uint256 constant TOKEN_10K = 1e22;
uint256 constant USDC_1 = 1e6;
uint256 constant MAXTIME = 4 * 365 * 86400; // 4 years
uint256 constant WEEK = 1 weeks;
```

### Environment Setup for Fork Tests
Set `BASE_RPC_URL` in `.env` file. Optionally set `BLOCK_NUMBER` for consistent fork state.

## Security Considerations

### Access Control
- Most contracts use role-based permissions (team, emergencyCouncil, etc.)
- VotingEscrow operations require NFT ownership verification
- Minter has exclusive rights to mint AERO tokens

### Reentrancy Protection
All state-changing functions use `ReentrancyGuard` from OpenZeppelin.

### Time Locks
- veNFT voting power decays linearly over time
- Permanent locks available to maintain constant voting power
- Managed NFTs are permanently locked by default

### Mathematical Precision
- Uses SafeCast library for type conversions
- High precision arithmetic with careful rounding
- Newton's method for stable pool calculations

## Common Development Tasks

### Adding New Pool Support
1. Ensure pool factory is registered in FactoryRegistry
2. Create gauge via Voter.createGauge()
3. Pools automatically get fee and bribe reward contracts

### Modifying Emission Logic
- Emissions controlled by Minter.sol with built-in growth/decay schedules
- Tail emissions can be adjusted via EpochGovernor voting
- Team emissions are percentage-based on total emissions

### Testing Pool Mechanics
- Use different pool types (stable vs volatile) for different asset pairs
- Test with various fee tiers and custom fees
- Verify K-invariant maintenance in swaps

## Key Dependencies

- **OpenZeppelin**: Core security and token standards
- **Foundry**: Testing and deployment framework
- **Solidity 0.8.19**: Specific version required
- **Base Network**: Primary deployment target

## Configuration Files

- **foundry.toml**: Foundry configuration with Base network settings
- **hardhat.config.ts**: Additional tooling configuration
- **package.json**: Node.js dependencies and scripts
- **script/constants/**: Deployment configuration templates