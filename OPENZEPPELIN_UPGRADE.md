# OpenZeppelin 5.x Upgrade Playbook

This guide captures the tasks required to migrate the DEX repository from OpenZeppelin Contracts 4.8.x to the 5.x release line.

## 1. Pre-Upgrade Checklist
- **Review release notes:** Read the official `v5.0.0`+ changelog and security advisories to understand breaking API changes.
- **Solidity version:** OZ 5.x requires `pragma >=0.8.20`; ensure all contracts, tests, and scripts use `pragma solidity 0.8.20;` and keep Foundry/Hardhat compiler targets aligned.
- **Dependency tree:** Confirm no other packages pin OZ 4.x. For Foundry libraries under `lib/`, note any forks that import 4.x helpers.
- **Branching:** Create a feature branch (e.g., `chore/oz-5-upgrade`) to isolate changes and enable incremental PRs.

## 2. Dependency Updates
- **package.json:** Bump `"@openzeppelin/contracts"` to `^5.x` and run `yarn install`.
- **Foundry lib:** Run `forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit` (or desired tag), then prune the old `lib/openzeppelin-contracts` version.
- **Remappings:** Verify `remappings.txt` still targets `lib/openzeppelin-contracts`; adjust if directory layout changes.
- **Lockfiles:** Update `yarn.lock` and `foundry.lock`; commit regenerated files.

## 3. Source Code Changes
- **Pragma bump:** Update every Solidity file (contracts, scripts, tests, mocks) to `pragma solidity 0.8.20;` or higher. Ensure external dependencies compiled with the same version.
- **Access control & modifiers:** Review use of `Ownable`, `Pausable`, `ReentrancyGuard`, etc. OZ 5 replaces revert strings with custom errors and tightens visibility; refactor any `require` string checks relying on previous behavior.
- **Math helpers:** `Math.mulDiv` now returns `uint256` without rounding enum arguments; verify existing calls compile and behave as expected.
- **ERC20 extensions:** If extending OZ tokens, align overrides with the new `IERC20` virtual functions and decimal handling changes.
- **Forwarder:** Confirm `@opengsn` forwarder still compiles against OZ 5 (or vendor pin a compatible commit).

## 4. Testing & Validation
- **Foundry:** Run `forge build` then `forge test --gas-report` to catch compilation or interface regressions. Include `forge test --ffi` if scripts depend on FFI.
- **TypeScript tooling:** Execute `npx hardhat test` when ABI consumers rely on OZ contracts to ensure generated types stay valid.
- **Gas/behavior audit:** Compare gas snapshots and key flows (swap, add/remove liquidity, fee claims) against main branch to detect functional drift.
- **Static analysis:** Re-run `yarn lint` and `yarn format:check`; consider `slither`/`mythril` scans if previously part of the pipeline.

## 5. Rollout Strategy
- **Incremental PRs:** Ship the upgrade in stages—pragma bump, dependency bump, contract fixes, testing—so reviewers can isolate regressions.
- **Docs & tooling:** Update `AGENTS.md`, `SPECIFICATION.md`, and deployment playbooks to reflect the new Solidity baseline and OZ version.
- **Release coordination:** Communicate upgrade impact (e.g., re-audits, deployment scripts) to downstream integrators before merging to main.

## 6. Post-Merge Follow-Up
- **Tag & release:** Publish a changelog noting OZ 5 adoption and any contract interface changes.
- **Monitor deployments:** For live networks, redeploy only after verifying bytecode diffs and running fork tests against Base RPCs.
- **Backport security fixes:** Track future OZ 5.x patches; schedule periodic dependency bumps to stay current.
