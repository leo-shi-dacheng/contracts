# Repository Guidelines

This guide helps new contributors ramp quickly on the protocol repository.

## Project Structure & Module Organization
- `contracts/`: core Solidity modules grouped by feature (`factories/`, `gauges/`, `governance/`, `rewards/`).
- `contracts/libraries/`: reusable math, token, and time helpers; contribute internal utilities here instead of duplicating.
- `script/`: Foundry `.s.sol` deployment and upkeep scripts; third-party dependencies sit under `lib/`.
- `test/`: Foundry integration suites; use `test/utils` for fixtures or mocks and record complex flows in `test/e2e`.

## Build, Test, and Development Commands
- `forge build`: compile all contracts into `out/` before committing ABI-sensitive changes.
- `forge test -vv`: execute the full Solidity test suite with traces for debugging.
- `forge test --match-contract Router`: narrow runs while iterating on specific suites.
- `forge test --ffi`: enable external tooling for scripts mirroring CI behaviour.
- `npx hardhat test`: run JavaScript-based validations such as ABI comparisons.
- `yarn format`, `yarn format:check`, `yarn lint`: enforce formatting and linting prior to review.

## Coding Style & Naming Conventions
- Start files with `// SPDX-License-Identifier: MIT` and `pragma solidity 0.8.20;`.
- Use 4-space indentation and group imports by origin (OpenZeppelin, external, local).
- Name interfaces with the `I` prefix, contracts and libraries in PascalCase, immutables in `UPPER_CASE`, and storage variables in snake_case.
- Place shared internal helpers in `contracts/libraries/` and avoid unchecked blocks without justification comments.

## Testing Guidelines
- Create Foundry tests alongside their domain using the `*.t.sol` pattern and inherit from `BaseTest` for shared setup.
- Document new end-to-end scenarios under `test/e2e` and keep fixtures in `test/utils`.
- Run `forge test -vv` (or targeted matches) locally before PRs; include `--ffi` when scripts rely on external binaries.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (e.g., `feat: deploy to base`, `fix: adjust rewards gauge`).
- PRs should clearly state the problem, link issues, and summarize solution impact.
- Attach pertinent gas metrics or deployment artifacts when costs change, and add screenshots only for documentation updates.
- Re-run `forge test` and `yarn format:check` before requesting review to keep CI green.

## Security & Configuration Tips
- Load secrets (RPC URLs, scan keys, Tenderly credentials) from environment variables referenced in `foundry.toml`.
- Avoid hardcoded addresses; extend factories or config modules and document changes in `SPECIFICATION.md`.
- Route privileged execution paths through `ProtocolForwarder` and keep multisig roles aligned with `governance/` contracts.


  - contracts/Pool.sol: 稳定池 _get_y 仍以固定 255 次迭代求解且频繁重复读取 reserve0/1，建议加入自适应收敛和本地缓存，并用自定义错误取代 "!y" 字符串以减少 gas 与
  revert 成本。
  - contracts/Router.sol: quoteAddLiquidity / quoteRemoveLiquidity 要求显式 _factory，与路由 Route.factory = address(0) 默认逻辑不一致；应统一为零地址时回落至
  defaultFactory 或尽早 revert，避免调用方踩坑。
  - PoolFactory 暂停语义: 目前 swap 会 isPaused，但 mint/burn/createPool 未受限；若希望停服时完全冻结资金流，需扩展暂停检查或在文档中澄清仅阻断交易。
  - 文档对齐: SPECIFICATION.md、README.md 和多份分析报告仍描述 Gauge、VotingEscrow 等已移除模块，需更新成“DEX 精简版”架构或补回缺失合约，避免集成方误解接口范围。

  性能优化

  - 状态缓存: swap、mint、burn 等函数多次读取 reserve/token，可提前缓存在内存中并使用 unchecked 包裹安全的乘加，结合 forge test --gas-report 验证收益。
  - 稳定池数学: 目前 _f / _d 连续除法导致精度损耗，可延迟除法并使用更高位中间结果（参考 优化.md 建议）以提升稳定曲线准确度。
  - 路由批量操作: 缺乏批量换币/流动性接口，前端高频调用 gas 成本高；可封装 batchSwap / batchAddLiquidity 等以复用现有逻辑。

  测试验证

  - 负面场景: 现有 Foundry 测试覆盖快乐路径，尚未验证暂停、手续费定制、稳定池流动性不匹配、HSK 包装出错等分支，建议扩展 *.t.sol 并加入 fuzz / invariant。
  - 脚本回归: DeployDex.s.sol 未在 CI 运行，可添加 forge script ... --dry-run 或 snapshot 测试保证参数/JSON 输出稳定。
  - 多池交互: 组合路由、多跳路径、fee-on-transfer 代币、flashloan 回调等关键流程需新建 e2e 场景，避免上线后才发现断路。

  文档与流程

  - 贡献指引一致性: 新增的 AGENTS.md 与旧文档存在重复/冲突，需统一到单一来源并在 PR 模板中引用。
  - 权限手册: PERMISSIONS.md 仍包含 TODO 链接和过期角色描述，建议补齐现网地址及职责。
  - 迭代表: 项目内多份 research/analysis 文档缺少更新日期，可添加 changelog 或在 README 汇总最新结论。

  依赖与配置

  - 库版本: @openzeppelin/contracts@4.8.0 与主网常用 4.9.x/5.x 存在安全修复差距，需评估升级计划；lib/gsn 体积大、含 TODO，若仅用 Forwarder 可替换为最小化子模块。
  - 构建配置: foundry.toml 默认 via_ir=true 会拖慢本地编译，可提供 profile.dev 关闭以便开发；fs_permissions 授予根目录写权限，记得在 CI 环境确认安全。
  - NPM 脚本: yarn lint 带 --fix 容易无意修改文件，建议拆分为只读与自动修复两个命令并在文档中明确。
