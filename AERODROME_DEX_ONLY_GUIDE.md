# DEX-Only Configuration Guide

This guide summarizes the changes required to run the protocol as a pure automated market maker (AMM) without the liquidity mining, gauges, or vote-escrow (ve) subsystem. Follow the checklist below to trim the deployment, codebase, and tests down to the DEX core while keeping future reintegration straightforward.

## 1. Target Scope
- Keep constant-product/stable pools (`contracts/Pool.sol`) and liquidity plumbing (`PoolFactory`, `PoolFees`, `Router`).
- Retain shared math/token utilities in `contracts/libraries/`.
- Optionally keep the meta-transaction forwarder (`ProtocolForwarder`) if you still want ERC-2771 support.
- Defer/disable everything related to emissions, veNFTs, bribes, rewards, and governance (gauges, voter, minter, distributors, airdrops, governors).

## 2. Contracts to Keep vs Park
| Keep (DEX) | Park (ve / mining stack) |
| --- | --- |
| `contracts/Pool.sol`, `contracts/PoolFees.sol` | `contracts/VotingEscrow.sol`, `contracts/Voter.sol` |
| `contracts/Router.sol` (after edits below) | `contracts/Minter.sol`, `contracts/RewardsDistributor.sol` |
| `contracts/factories/PoolFactory.sol` | `contracts/gauges/Gauge.sol`, `contracts/rewards/*` |
| `contracts/factories/FactoryRegistry.sol` (slim) | `contracts/Aero.sol`, `contracts/VeArtProxy.sol`, `contracts/AirdropDistributor.sol` |
| `contracts/ProtocolForwarder.sol` (optional) | `contracts/governance/*`, `contracts/factories/*Gauge*`, `contracts/factories/*Rewards*` |

> Tip: Keep the parked contracts in-tree so future feature work diff stays minimal, but exclude them from builds/tests for now.

## 3. Code Adjustments

1. **Pool admin without `Voter`**  
   - `contracts/Pool.sol:101` and `contracts/Pool.sol:107` gate `setName` / `setSymbol` through `IVoter(_voter).emergencyCouncil()`. Replace this dependency with a simple admin (e.g., `PoolFactory.pauser()` or a new immutable) and remove the `IVoter` import.
   - `contracts/factories/PoolFactory.sol:25` currently stores `voter` in the constructor. If you drop `Voter`, change `voter` to an admin address set at deployment and adjust `setVoter` / emitted events accordingly.

2. **Router without gauges**  
   - Remove the `IVoter` / `IGauge` imports at `contracts/Router.sol:29` and the staking branch in `zapIn` around `contracts/Router.sol:534`. Replace the boolean `stake` argument with a no-op or delete it to simplify the ABI.  
   - Update `_zapInLiquidity` caller to return LP tokens directly to the user once minted.  
   - If you still want factory whitelisting, keep `factoryRegistry`; otherwise expose a simpler `poolFor` that trusts the default factory.

3. **Factory registry simplification**  
   - `contracts/factories/FactoryRegistry.sol` enforces coupled voting/gauge factories. Introduce a lightweight registry that only tracks pool factories (or hardcode the single `PoolFactory` address). This lets you drop `votingRewardsFactory`/`gaugeFactory` storage and related events.

4. **Interfaces cleanup**  
   - Prune unused interfaces under `contracts/interfaces/` (e.g., `IVoter`, `IGauge`, `IVotingEscrow`, `IMinter`). Keep copies in place if you expect to re-enable features later, but remove import usage from live contracts to avoid compilation.

5. **Deployment library updates**  
   - Verify libraries in `contracts/libraries/` are still referenced. Dead code (e.g., vote-weight math) can be left but should be excluded from compilation to keep bytecode lean.

## 4. Deployment & Scripts

1. **Foundry 部署脚本**  
   - 使用 `script/DeployDex.s.sol` 部署 `ProtocolForwarder`、`Pool` 实现、`PoolFactory` 与 `Router`，并根据环境变量写出 `script/constants/output/{OUTPUT_FILENAME}`。  
   - 可复制 `script/constants/template.json` 生成多套配置（如不同网络），不再维护旧的 `DeployCore.s.sol`。

2. **移除遗留脚本**  
   - `DeployGaugesAndPools`、`DeployGovernors`、`DistributeAirdrops` 等脚本已废弃，README 已标注仅保留 Foundry 流程；仓库不再提供 Hardhat 版本。

## 5. Build/Test Configuration

1. **Foundry build filters**  
   - Add a new profile to `foundry.toml` such as:
     ```toml
     [profile.dex]
     src = 'contracts'
     ignored_files = [
       'contracts/VotingEscrow.sol',
       'contracts/Voter.sol',
       'contracts/gauges/Gauge.sol',
       'contracts/Minter.sol',
       'contracts/RewardsDistributor.sol'
     ]
     ```
     Then run `forge build --profile dex` to exclude the ve stack.

2. **测试范围**  
   - 仅保留核心 DEX 测试：`test/Pool.t.sol`、`test/PoolFactory.t.sol`、`test/PoolFees.t.sol`、`test/Router.t.sol`。其他 ve/激励相关测试已删除。

3. **CI 更新**  
   - CI 流程只需执行 `forge build`、`forge test` 以及 `yarn format:check`、`yarn lint:check`，无需再生成 TypeChain 或 Hardhat 产物。

## 6. Housekeeping

- Update top-level docs (`README.md`, `SPECIFICATION.md`) to reflect the temporary DEX-only scope and link back to this file.
- Flag TODOs in the code where ve-specific logic was removed so future reintegration is simple.
- Review `PERMISSIONS.md` to match the reduced role set (only fee manager / pauser / admin).
- Run `forge fmt` / `yarn format:check` after edits to ensure style consistency.

## 7. Re-enabling ve/mining (future)

When you are ready to restore gauges and ve mechanics, revert the router staking hooks, point `PoolFactory` back to a live `Voter`, reintroduce the deployment steps, and re-enable the excluded tests/profile. Keeping the parked contracts untouched now will keep that diff manageable.
