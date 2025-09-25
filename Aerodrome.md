# Aerodrome 协议研究报告

## 1. 执行摘要
Aerodrome 是部署在 Base 链上的下一代自动做市商 (AMM) 协议，由 Velodrome 团队基于 Solidly 架构重写并强化。协议以双池 AMM、veTokenomics、Gauge 激励和多层治理为核心，通过严格的权限控制与完善的测试体系实现安全可扩展的流动性网络。本报告综合仓库内所有技术文档与测试材料，对协议现状、经济模型、安全措施及未来演进方向进行系统性分析。

## 2. 项目背景与目标
- **愿景**：在 Coinbase 生态支持下，为 Base 链提供具备长期激励、专业治理与高流动性效率的公共基础设施。
- **设计目标**：兼顾稳定资产与波动资产交易体验；通过 veNFT 锁仓机制绑定长期利益；建立可审计、可升级的工厂体系；支持专业化托管与委托治理。
- **技术栈**：Solidity 0.8.19、Foundry 测试与部署工具链、Hardhat 辅助脚本、OpenZeppelin 安全库。代码以 Business Source License 1.1 授权，2025-06-01 转为 GPLv2。

## 3. 核心架构概览
### 3.1 AMM 与流动性层
- `Pool.sol` 同时实现恒定乘积 (`xy = k`) 和稳定曲线 (`x^3y + xy^3 = k`) 两套定价模型，通过牛顿迭代求解稳定池兑换量，支持自定义费率及 fee-on-transfer 资产。
- `Router.sol` 提供多跳路径、ZAP、一键质押/解押等操作，由前端/聚合器提供路由序列。
- `PoolFactory.sol` 与 `FactoryRegistry.sol` 负责池子、Gauge、奖励工厂注册，支持升级兼容与权限审计。

### 3.2 Tokenomics 与投票系统
- `Aero.sol` 为极简 ERC-20，铸造权完全委托给 `Minter.sol`。
- `VotingEscrow.sol` 将锁仓 AERO 铸造成 veNFT，最长锁期四年，权重线性衰减，可永久锁、分割、合并、托管与委托。`VOTINGESCROW.md` 提供状态机与检查点细节。
- `Minter.sol` 实现每周 1% 衰减的发行曲线，当周发行低于 600 万 AERO 时进入尾部发行，由 `EpochGovernor` 以 ±1 bp 调节。

### 3.3 治理与激励分发
- `Voter.sol` 汇总 veNFT 投票，按照周度 epoch 分配 Gauge 激励，创建/管理 Gauge，支持批量领取费用与贿赂，限制首尾小时操作以避免竞态。
- `Gauge.sol`、`RewardsDistributor.sol`、`BribeVotingReward.sol`、`FeesVotingReward.sol`、`ManagedReward` 系列构成多层奖励网络，覆盖 LP 挖矿、投票费用分润、第三方贿赂与托管收益。
- `ProtocolGovernor.sol` 基于 OpenZeppelin Governor，实现提案、投票、Vetoer 机制；`EpochGovernor.sol` 专注尾部发行调节的简单多数制投票。

## 4. 经济模型与价值捕获
- **ve(3,3) 激励**：锁仓换取 veNFT，投票决定 Gauge 激励倾斜；投票者可领取交易费、第三方 Bribe、定期 Rebases。
- **发行机制**：初始 1500 万 AERO/周，1% 线性衰减；尾部发行与团队分成由治理调节，协议可应对市况变化。
- **托管与委托**：Managed veNFT 支持专业化策略，`LockedManagedReward` 与 `FreeManagedReward` 实现复投与收益分配，促进机构级参与。
- **生态协同**：Router ZAP、脚本部署与 FactoryRegistry 允许外部项目快速创建池子与激励通道，推动 Base 生态网络效应。

## 5. 安全与权限控制
- `PERMISSIONS.md` 定义多重签名、Emergency Council、Pauser、FeeManager、AllowedManager 等角色，细化到池工厂、投票白名单、Gauge 杀活等操作。
- 合约广泛应用 `ReentrancyGuard`、`SafeERC20`、显式权限校验；`Voter`、`Pool`、`Gauge` 在关键路径采用非可重入设计。
- 稳定池新增 K 值检测、费用分离 (`PoolFees.sol`)，降低资金挪用与夹带风险。
- 许可模式：核心合约不可升级，工厂可迭代部署新版，用户自主迁移。

## 6. 测试体系与开发流程
- `test/` 目录包含 40+ 份 Foundry 测试：单元 (`*.t.sol`)、端到端 (`test/e2e`)、Fork 测试、特殊场景（Oracle、Zap、WashTrade、Imbalance）。`AERODROME_TEST_ANALYSIS.md` 阐述各测试目标与覆盖面。
- `BaseTest.sol` 提供统一部署脚本、模拟账户与常量；支持 `Deployment.DEFAULT/FORK/CUSTOM` 模式。
- CI 建议：`forge test -vv`、`forge test --ffi`（含外部脚本）、`yarn format:check`、`yarn lint:check`。`CLAUDE.md` 与 `AGENTS.md` 给出贡献者规范与命令速查。

## 7. 运维与部署实践
- `foundry.toml` 配置 Base/Mainnet RPC、Etherscan 验证、写权限。脚本目录包含核心部署 (`DeployCore.s.sol`)、池与 Gauge、治理部署。
- 生产部署地点集中在 Base 主网，`README.md` 列出核心合约地址；`PERMISSIONS.md` 提供多签地址与治理角色信息。
- 许可将于 2025-06-01 自动转换为 GPLv2，需提前规划商业化使用授权。

## 8. 优化与路线图
- `优化.md`、`AERODROME_ROUTER_OPTIMIZATION_PROPOSAL.md`、`AERODROME_UNISWAP_UPGRADE_ANALYSIS.md` 提出未来方向：
  - 数学优化：稳定池迭代自适应、延迟除法、精度提升、Halley 法候选。
  - 路由升级：引入自动路径发现、订单拆分、Gas 感知算法，可参考 Uniswap AutoRouter 与 1inch Pathfinder；探索意图驱动交易 (Intent) 与 Dutch Auction 策略。
  - MEV 保护：考虑 commit-reveal、延迟执行、私有内存池；动态价格快照、异常检测。
  - 流动性效率：集中流动性、动态费率、批量操作接口、单边注入；智能激励分配器。
  - 多链扩展：标准化跨链接口与渐进式升级机制。

## 9. 风险评估
- **技术风险**：
  - 稳定池迭代在极端输入下的收敛与精度需持续验证；批量操作缺失影响 Gas；复杂托管逻辑增加攻击面。
  - 工厂升级需完善审计与迁移机制，避免用户资产停留旧版。
- **经济风险**：
  - 大户/协议操纵投票导致激励倾斜；尾部发行调整可能滞后市场；稳定池高曲线复杂度需监控滑点。
- **运营风险**：
  - 多重签名失效或治理提案攻击；许可转换带来的合规要求；Base 网络拥堵对用户体验的影响。
- **缓解措施**：保持多重签名安全、定期审计与监控、设计渐进式升级流程，强化社区投票透明度与风控指标。

## 10. 结论与建议
Aerodrome 已构建完整的 AMM + ve(3,3) 基础设施：
- **优势**：双池架构覆盖多资产场景；veNFT 驱动长期参与；治理与权限拆分细致；测试体系成熟；文档详备。
- **短期重点**：推进稳定池数学与 Router 路由优化、完善 MEV 保护、扩充批量与意图交易工具。
- **中长期规划**：探索集中流动性、意图层、跨链部署与智能激励；在许可转换前完善商业授权策略；继续吸引 Base 生态项目与专业 LP 合作。

凭借成熟的架构与清晰的优化路径，Aerodrome 有望在 Base 链乃至更广泛的 EVM 生态中保持领先地位。本报告建议项目团队循序推进优化路线，同时维持严格的测试、安全与治理准则，以巩固协议的可持续竞争力。
