# Repository Guidelines

## Project Structure & Module Organization
The core protocol lives in `contracts/`, with feature folders (`factories/`, `gauges/`, `governance/`, `rewards/`) for modular code that mirrors on-chain responsibilities. Shared math, time, and token logic sits in `contracts/libraries/`. Deployment helpers and automation scripts are in `script/` (Foundry `.s.sol`). Vendor packages live under `lib/`. Solidity integration tests are in `test/`, with reusable fixtures in `test/utils`.

## Build, Test & Development Commands
Run `forge build` to compile all contracts to `out/`. Use `forge test -vv` for verbose diagnostics, or scope runs with `forge test --match-contract Router`. JavaScript-based tasks (ABI generation, coverage) can reuse `npx hardhat test`. Enforce formatting with `yarn format` and lint solidity best practices with `yarn lint`. Use the `:check` variants in CI or before pushing to avoid rewriting files.

## Coding Style & Naming Conventions
All Solidity files start with SPDX headers and `pragma solidity 0.8.19;`. Indent four spaces and group imports by origin (`@openzeppelin`, external interfaces, local). Contracts and libraries use PascalCase, interfaces keep the `I` prefix, immutable constants are `UPPER_CASE`, and storage variables are concise snake_case. Prefer explicit visibility, unchecked blocks only beside comments, and internal helpers in `libraries/` when shared.

## Testing Guidelines
Place Foundry unit tests beside the domain they cover using the `*.t.sol` convention; inherit from `BaseTest` when setup is shared. Mock deployments belong in `test/utils`. Run regression suites with `forge test --ffi` whenever scripts rely on external tooling. Snapshot any new scenario flows under `test/e2e` and document assumptions in file headers.

## Commit & Pull Request Guidelines
Follow the existing Conventional Commit style (`type: summary`, e.g., `feat: deploy to base`). Each PR should include a clear problem statement, linked issue or context, and a checklist of new tests or rationale when tests are skipped. Attach gas or deployment artifacts when the change modifies execution cost, and add screenshots only when UI docs are affected. Re-run `yarn format:check` and `forge test` before requesting review.

## Security & Configuration Notes
Secrets such as RPC URLs, scan keys, and Tenderly credentials are injected via environment variables referenced in `foundry.toml`. Avoid hardcoding addresses; instead extend the factories or config modules and document them in `SPECIFICATION.md`. For deployments, rely on meta-transactions through `ProtocolForwarder`, ensuring multisig roles are updated in `governance/` contracts.
