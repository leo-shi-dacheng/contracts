# Aerodrome 核心合约深度解读

## 概述

本文档深入分析 Aerodrome 协议的七个核心合约，详细解读每个合约的设计理念、核心功能、关键机制和安全特性。

## 1. Aero.sol - 原生代币合约

### 合约概述
`Aero.sol` 是协议的原生 ERC-20 代币合约，采用极简设计理念，功能纯粹且安全。

### 关键特性

#### 继承结构
```solidity
contract Aero is IAero, ERC20Permit {
    // 继承标准 ERC20 和 ERC20Permit 扩展
}
```

#### 核心状态变量
- `address public minter`: 唯一有权铸造代币的地址
- `address private owner`: 私有所有者地址（实际未使用）

#### 关键功能

**1. 铸造权限控制**
```solidity
function mint(address account, uint256 amount) external returns (bool) {
    if (msg.sender != minter) revert NotMinter();
    _mint(account, amount);
    return true;
}
```

**2. 铸造者转移**
```solidity
function setMinter(address _minter) external {
    if (msg.sender != minter) revert NotMinter();
    minter = _minter;
}
```

### 设计亮点

1. **极简主义**: 只包含必要的铸造功能，减少攻击面
2. **单一责任**: 铸造权限集中在 Minter 合约
3. **ERC20Permit**: 支持无 gas 授权，提升用户体验
4. **无管理员功能**: 除铸造外无其他特殊权限

## 2. VotingEscrow.sol - veNFT 投票锁定系统

### 合约概述
`VotingEscrow.sol` 是协议的核心治理合约，实现了 veTokenomics 模型，将 AERO 代币锁定转换为具有投票权重的 NFT。

### 关键数据结构

#### 锁定余额结构
```solidity
struct LockedBalance {
    int128 amount;        // 锁定数量
    uint256 end;          // 锁定结束时间
    bool isPermanent;     // 是否永久锁定
}
```

#### 用户点位结构
```solidity
struct UserPoint {
    int128 bias;          // 当前投票权重
    int128 slope;         // 权重衰减斜率
    uint256 ts;           // 时间戳
    uint256 blk;          // 区块号
    uint256 permanent;    // 永久锁定权重
}
```

#### NFT 类型枚举
```solidity
enum EscrowType {
    NORMAL,   // 普通 veNFT
    LOCKED,   // 被锁定到托管 NFT 中
    MANAGED   // 托管 NFT，可接受其他 NFT 委托
}
```

### 核心机制

#### 1. 投票权重计算
投票权重采用线性衰减模型：
- 初始权重 = 锁定数量 × 剩余锁定时间 / 最大锁定时间
- 权重随时间线性递减，激励长期持有

#### 2. 检查点系统
```solidity
function _checkpoint(
    uint256 _tokenId, 
    LockedBalance memory oldLocked, 
    LockedBalance memory newLocked
) internal {
    // 更新用户和全局检查点
    // 计算权重变化
    // 记录历史状态
}
```

#### 3. NFT 生命周期管理

**创建锁定**
```solidity
function createLock(uint256 _value, uint256 _lockDuration) 
    external nonReentrant returns (uint256) {
    return _createLock(_value, _lockDuration, _msgSender());
}
```

**增加数量**
```solidity
function increaseAmount(uint256 _tokenId, uint256 _value) external {
    _increaseAmountFor(_tokenId, _value, DepositType.INCREASE_LOCK_AMOUNT);
}
```

**延长时间**
```solidity
function increaseUnlockTime(uint256 _tokenId, uint256 _lockDuration) external {
    // 延长锁定时间，增加投票权重
}
```

#### 4. 托管 NFT 系统
- **MANAGED NFT**: 专业管理的 veNFT，可接受其他用户委托
- **LOCKED NFT**: 被委托给 MANAGED NFT 的普通 NFT
- 支持委托挖矿和奖励分配

### 安全特性

1. **重入保护**: 使用 `ReentrancyGuard`
2. **时间验证**: 严格的锁定时间校验
3. **权限控制**: NFT 操作需要所有权验证
4. **溢出保护**: 使用 SafeCast 库

## 3. Pool.sol - AMM 流动性池

### 合约概述
`Pool.sol` 实现了支持稳定币和波动性代币的 AMM 池，是协议交易功能的核心。

### 池子类型

#### 1. 波动性池 (Volatile Pool)
- 使用恒定乘积公式: `x * y = k`
- 适用于价格波动较大的代币对
- 类似 Uniswap V2 机制

#### 2. 稳定币池 (Stable Pool)
- 使用曲线公式: `x³y + y³x = k`
- 适用于价值相近的代币对（稳定币、LST 等）
- 提供更低的滑点

### 关键状态变量

```solidity
bool public stable;                    // 池子类型标识
address public token0, token1;         // 代币对地址
uint256 public reserve0, reserve1;     // 储备量
address public poolFees;               // 费用收集合约
mapping(address => uint256) public claimable0, claimable1; // 用户可领取费用
```

### 核心功能

#### 1. 稳定币池定价算法

**不变量计算**
```solidity
function _k(uint256 x, uint256 y) internal view returns (uint256) {
    if (stable) {
        uint256 _x = (x * 1e18) / decimals0;
        uint256 _y = (y * 1e18) / decimals1;
        uint256 _a = (_x * _y) / 1e18;
        uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
        return (_a * _b) / 1e18; // x³y + y³x
    } else {
        return x * y; // x * y
    }
}
```

**牛顿迭代法求解**
```solidity
function _get_y(uint256 x0, uint256 xy, uint256 y) internal view returns (uint256) {
    // 使用牛顿迭代法求解 y 值
    // 最多迭代 255 次确保收敛
    for (uint256 i = 0; i < 255; i++) {
        uint256 k = _f(x0, y);
        if (k < xy) {
            uint256 dy = ((xy - k) * 1e18) / _d(x0, y);
            // 处理收敛情况
            y = y + dy;
        } else {
            uint256 dy = ((k - xy) * 1e18) / _d(x0, y);
            y = y - dy;
        }
    }
}
```

#### 2. 流动性管理

**添加流动性**
```solidity
function mint(address to) external nonReentrant returns (uint256 liquidity) {
    (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
    uint256 _balance0 = IERC20(token0).balanceOf(address(this));
    uint256 _balance1 = IERC20(token1).balanceOf(address(this));
    uint256 _amount0 = _balance0 - _reserve0;
    uint256 _amount1 = _balance1 - _reserve1;
    
    // 计算 LP 代币数量
    if (totalSupply == 0) {
        liquidity = Math.sqrt(_amount0 * _amount1) - MINIMUM_LIQUIDITY;
        _mint(address(0), MINIMUM_LIQUIDITY); // 永久锁定最小流动性
    } else {
        liquidity = Math.min(
            (_amount0 * totalSupply) / _reserve0,
            (_amount1 * totalSupply) / _reserve1
        );
    }
    
    _mint(to, liquidity);
    _update(_balance0, _balance1, _reserve0, _reserve1);
}
```

#### 3. 交易执行

**交换函数**
```solidity
function swap(
    uint256 amount0Out,
    uint256 amount1Out,
    address to,
    bytes calldata data
) external nonReentrant {
    // 验证输出数量
    if (amount0Out == 0 && amount1Out == 0) revert InsufficientOutputAmount();
    
    // 执行交换
    if (amount0Out > 0) IERC20(token0).safeTransfer(to, amount0Out);
    if (amount1Out > 0) IERC20(token1).safeTransfer(to, amount1Out);
    
    // 回调处理（用于闪电贷）
    if (data.length > 0) IPoolCallee(to).hook(msg.sender, amount0Out, amount1Out, data);
    
    // 验证 K 值不变性
    uint256 _balance0 = IERC20(token0).balanceOf(address(this));
    uint256 _balance1 = IERC20(token1).balanceOf(address(this));
    
    if (_balance0 * _balance1 < uint256(reserve0) * uint256(reserve1)) revert K();
    
    _update(_balance0, _balance1, reserve0, reserve1);
}
```

#### 4. 预言机功能

**价格累积器**
```solidity
struct Observation {
    uint256 timestamp;
    uint256 reserve0Cumulative;
    uint256 reserve1Cumulative;
}

Observation[] public observations;

function _update(uint256 balance0, uint256 balance1, uint256 _reserve0, uint256 _reserve1) internal {
    uint256 timeElapsed = block.timestamp - blockTimestampLast;
    if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
        reserve0CumulativeLast += _reserve0 * timeElapsed;
        reserve1CumulativeLast += _reserve1 * timeElapsed;
    }
    
    // 每 30 分钟记录一次观察点
    if (timeElapsed > periodSize) {
        observations.push(Observation(
            block.timestamp, 
            reserve0CumulativeLast, 
            reserve1CumulativeLast
        ));
    }
}
```

### 费用机制

#### 1. 费用收集
- 交易费用存储在独立的 `PoolFees` 合约中
- 费用按 LP 份额比例分配给用户
- 支持随时领取累积费用

#### 2. 费用分配算法
```solidity
function _updateFor(address recipient) internal {
    uint256 _supplied = balanceOf[recipient];
    if (_supplied > 0) {
        uint256 _supplyIndex0 = supplyIndex0[recipient];
        uint256 _supplyIndex1 = supplyIndex1[recipient];
        uint256 _index0 = index0;
        uint256 _index1 = index1;
        
        // 计算新增费用
        uint256 _delta0 = _index0 - _supplyIndex0;
        uint256 _delta1 = _index1 - _supplyIndex1;
        
        if (_delta0 > 0) {
            uint256 _share = (_supplied * _delta0) / 1e18;
            claimable0[recipient] += _share;
        }
        if (_delta1 > 0) {
            uint256 _share = (_supplied * _delta1) / 1e18;
            claimable1[recipient] += _share;
        }
    }
}
```

## 4. Router.sol - 路由合约

### 合约概述
`Router.sol` 是用户与协议交互的主要入口，提供多池路由、流动性管理和复杂交易功能。

### 核心功能

#### 1. 多池路由交换

**路由结构**
```solidity
struct Route {
    address from;      // 输入代币
    address to;        // 输出代币
    bool stable;       // 池子类型
    address factory;   // 工厂地址
}
```

**多跳交换**
```solidity
function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    Route[] calldata routes,
    address to,
    uint256 deadline
) external ensure(deadline) returns (uint256[] memory amounts) {
    amounts = getAmountsOut(amountIn, routes);
    if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();
    
    _safeTransferFrom(routes[0].from, msg.sender, poolFor(routes[0]), amounts[0]);
    _swap(amounts, routes, to);
}
```

#### 2. 流动性管理

**添加流动性**
```solidity
function addLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
) public ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
    // 计算最优添加数量
    (amountA, amountB) = _addLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, amountAMin, amountBMin);
    
    // 转移代币到池子
    address pool = poolFor(tokenA, tokenB, stable, defaultFactory);
    _safeTransferFrom(tokenA, msg.sender, pool, amountA);
    _safeTransferFrom(tokenB, msg.sender, pool, amountB);
    
    // 铸造 LP 代币
    liquidity = IPool(pool).mint(to);
}
```

#### 3. Zapping 功能

**一键添加流动性**
```solidity
function zapIn(
    address tokenIn,
    uint256 amountInA,
    uint256 amountInB,
    Zap memory zapInPool,
    Route[] calldata routesA,
    Route[] calldata routesB,
    address to,
    bool stake
) external payable returns (uint256 liquidity) {
    // 将单一代币转换为 LP 代币对
    // 支持直接质押到 Gauge
}
```

#### 4. ETH 支持

**ETH 交换**
```solidity
function swapExactETHForTokens(
    uint256 amountOutMin,
    Route[] calldata routes,
    address to,
    uint256 deadline
) external payable ensure(deadline) returns (uint256[] memory amounts) {
    if (routes[0].from != address(weth)) revert InvalidPath();
    amounts = getAmountsOut(msg.value, routes);
    if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();
    
    weth.deposit{value: amounts[0]}();
    assert(weth.transfer(poolFor(routes[0]), amounts[0]));
    _swap(amounts, routes, to);
}
```

### 安全机制

1. **截止时间检查**: 防止交易在延迟后执行
2. **滑点保护**: 最小输出数量验证
3. **路径验证**: 确保路由路径有效
4. **重入保护**: 关键操作添加重入保护

## 5. Voter.sol - 投票治理合约

### 合约概述
`Voter.sol` 是协议的治理核心，管理 veNFT 投票、奖励分配和 Gauge 创建。

### 核心数据结构

#### 投票相关映射
```solidity
mapping(address => address) public gauges;           // 池子 => Gauge 地址
mapping(address => uint256) public weights;          // 池子权重
mapping(uint256 => mapping(address => uint256)) public votes; // NFT => 池子 => 投票权重
mapping(uint256 => address[]) public poolVote;       // NFT 投票的池子列表
mapping(uint256 => uint256) public usedWeights;      // NFT 已使用的权重
mapping(uint256 => uint256) public lastVoted;        // NFT 最后投票时间
```

#### 奖励分配
```solidity
mapping(address => uint256) public claimable;        // Gauge 可领取奖励
mapping(address => bool) public isAlive;             // Gauge 活跃状态
```

### 核心功能

#### 1. 投票机制

**投票流程**
```solidity
function vote(
    uint256 _tokenId,
    address[] calldata _poolVote,
    uint256[] calldata _weights
) external onlyNewEpoch(_tokenId) nonReentrant {
    // 验证投票权限
    if (!IVotingEscrow(ve).isApprovedOrOwner(msg.sender, _tokenId)) revert NotApprovedOrOwner();
    
    // 验证参数
    if (_poolVote.length != _weights.length) revert UnequalLengths();
    if (_poolVote.length > maxVotingNum) revert TooManyPools();
    
    // 获取 NFT 投票权重
    uint256 _weight = IVotingEscrow(ve).balanceOfNFT(_tokenId);
    
    // 执行投票
    _vote(_tokenId, _weight, _poolVote, _weights);
}
```

**投票处理逻辑**
```solidity
function _vote(
    uint256 _tokenId, 
    uint256 _weight, 
    address[] memory _poolVote, 
    uint256[] memory _weights
) internal {
    _reset(_tokenId); // 重置之前的投票
    
    uint256 _totalVoteWeight = 0;
    for (uint256 i = 0; i < _poolVote.length; i++) {
        _totalVoteWeight += _weights[i];
    }
    
    for (uint256 i = 0; i < _poolVote.length; i++) {
        address _pool = _poolVote[i];
        address _gauge = gauges[_pool];
        
        // 计算池子权重
        uint256 _poolWeight = (_weights[i] * _weight) / _totalVoteWeight;
        
        // 更新状态
        weights[_pool] += _poolWeight;
        votes[_tokenId][_pool] += _poolWeight;
        
        // 分配奖励权重
        IReward(gaugeToFees[_gauge])._deposit(_poolWeight, _tokenId);
        IReward(gaugeToBribe[_gauge])._deposit(_poolWeight, _tokenId);
    }
    
    totalWeight += _totalWeight;
    usedWeights[_tokenId] = _usedWeight;
}
```

#### 2. Gauge 管理

**创建 Gauge**
```solidity
function createGauge(
    address _poolFactory,
    address _pool
) external returns (address _gauge, address _feeVotingReward, address _bribeVotingReward) {
    // 验证工厂和池子
    if (!IFactoryRegistry(factoryRegistry).isPoolFactoryApproved(_poolFactory)) revert NotApprovedFactory();
    if (gauges[_pool] != address(0)) revert GaugeExists();
    
    // 创建 Gauge 和奖励合约
    _gauge = IGaugeFactory(gaugeFactory).createGauge(_forwarder, _pool, address(this), address(rewardToken), _isPool);
    
    // 创建投票奖励合约
    address _votingRewardsFactory = IFactoryRegistry(factoryRegistry).votingRewardsFactories(_poolFactory);
    _feeVotingReward = IVotingRewardsFactory(_votingRewardsFactory).createReward(address(this), new address[](0));
    _bribeVotingReward = IVotingRewardsFactory(_votingRewardsFactory).createReward(address(this), new address[](0));
    
    // 注册映射关系
    gauges[_pool] = _gauge;
    poolForGauge[_gauge] = _pool;
    gaugeToFees[_gauge] = _feeVotingReward;
    gaugeToBribe[_gauge] = _bribeVotingReward;
    isGauge[_gauge] = true;
    isAlive[_gauge] = true;
}
```

#### 3. 奖励分发

**分发流程**
```solidity
function distribute(uint256 start, uint256 finish) external nonReentrant {
    // 从 Minter 获取代币
    IMinter(minter).updatePeriod();
    
    // 遍历活跃的 Gauge
    for (uint256 x = start; x < finish; x++) {
        address _gauge = gauges[pools[x]];
        if (isAlive[_gauge]) {
            // 计算该 Gauge 应得奖励
            uint256 _claimable = claimable[_gauge];
            
            if (_claimable > DURATION) {
                claimable[_gauge] = 0;
                
                // 分发代币到 Gauge
                IERC20(rewardToken).safeTransfer(_gauge, _claimable);
                IGauge(_gauge).notifyRewardAmount(_claimable);
            }
        }
    }
}
```

#### 4. 托管 NFT 功能

**委托到托管 NFT**
```solidity
function depositManaged(uint256 _tokenId, uint256 _mTokenId) external nonReentrant {
    // 验证权限和状态
    if (!IVotingEscrow(ve).isApprovedOrOwner(msg.sender, _tokenId)) revert NotApprovedOrOwner();
    if (IVotingEscrow(ve).deactivated(_mTokenId)) revert InactiveManagedNFT();
    
    // 执行委托
    IVotingEscrow(ve).depositManaged(_tokenId, _mTokenId);
    
    // 更新托管 NFT 的投票
    uint256 _weight = IVotingEscrow(ve).balanceOfNFTAt(_mTokenId, block.timestamp);
    _poke(_mTokenId, _weight);
}
```

### 时间控制机制

#### Epoch 系统
- **投票周期**: 每周四 00:00 UTC 开始新的 epoch
- **投票窗口**: 每个 epoch 的前几天允许投票
- **分发时机**: epoch 结束后分发奖励

```solidity
modifier onlyNewEpoch(uint256 _tokenId) {
    // 确保在新 epoch 或距离上次投票超过一周
    if (ProtocolTimeLibrary.epochStart(block.timestamp) <= lastVoted[_tokenId]) {
        revert AlreadyVotedOrDeposited();
    }
    _;
}
```

## 6. Minter.sol - 代币铸造合约

### 合约概述
`Minter.sol` 控制 AERO 代币的发行机制，实现了复杂的代币经济学模型，包括周期性发行、衰减机制和团队分配。

### 发行机制设计

#### 1. 发行参数
```solidity
uint256 public constant WEEKLY_DECAY = 9_900;     // 99% (1% 衰减)
uint256 public constant WEEKLY_GROWTH = 10_300;   // 103% (3% 增长)
uint256 public constant TAIL_START = 8_969_150 * 1e18; // 尾部发行阈值
uint256 public tailEmissionRate = 67;             // 尾部发行率 0.67%
uint256 public weekly = 10_000_000 * 1e18;        // 初始周发行量
uint256 public teamRate = 500;                    // 团队分配比例 5%
```

#### 2. 发行阶段

**增长阶段 (前 15 周)**
- 每周发行量增长 3%
- 激励早期参与者

**衰减阶段 (15 周后)**
- 每周发行量衰减 1%
- 逐步减少通胀压力

**尾部发行阶段**
- 当周发行量降至阈值时激活
- 按总供应量的固定比例发行

#### 3. 发行计算逻辑

**更新周期**
```solidity
function updatePeriod() external returns (uint256 _period) {
    _period = activePeriod;
    if (block.timestamp >= _period + WEEK) {
        epochCount++;
        _period = (block.timestamp / WEEK) * WEEK;
        activePeriod = _period;
        
        uint256 _weekly = weekly;
        uint256 _emission;
        uint256 _totalSupply = aero.totalSupply();
        bool _tail = _weekly < TAIL_START;
        
        if (_tail) {
            // 尾部发行：按总供应量比例
            _emission = (_totalSupply * tailEmissionRate) / MAX_BPS;
        } else {
            _emission = _weekly;
            if (epochCount < 15) {
                // 增长阶段
                _weekly = (_weekly * WEEKLY_GROWTH) / MAX_BPS;
            } else {
                // 衰减阶段
                _weekly = (_weekly * WEEKLY_DECAY) / MAX_BPS;
            }
            weekly = _weekly;
        }
        
        // 计算增长奖励和团队分配
        uint256 _growth = calculateGrowth(_emission);
        uint256 _teamEmissions = (teamRate * (_growth + _weekly)) / (MAX_BPS - teamRate);
        
        // 铸造所需代币
        uint256 _required = _growth + _emission + _teamEmissions;
        uint256 _balanceOf = aero.balanceOf(address(this));
        if (_balanceOf < _required) {
            aero.mint(address(this), _required - _balanceOf);
        }
        
        // 分配代币
        IERC20(aero).safeTransfer(team, _teamEmissions);
        IERC20(aero).safeApprove(address(rewardsDistributor), _growth);
        rewardsDistributor.checkpointToken();
        IERC20(aero).safeApprove(address(rewardsDistributor), 0);
        IERC20(aero).safeApprove(address(voter), _emission);
        voter.notifyRewardAmount(_emission);
        IERC20(aero).safeApprove(address(voter), 0);
    }
}
```

#### 4. 增长奖励机制

**计算公式**
```solidity
function calculateGrowth(uint256 _minted) public view returns (uint256 _growth) {
    uint256 _veTotal = ve.totalSupplyAt(activePeriod - 1);  // 锁定总量
    uint256 _aeroTotal = aero.totalSupply();               // 流通总量
    
    // 增长奖励 = 发行量 × (流通量 - 锁定量) / 流通量 × (流通量 - 锁定量) / 流通量 / 2
    return (((_minted * (_aeroTotal - _veTotal)) / _aeroTotal) * (_aeroTotal - _veTotal)) / _aeroTotal / 2;
}
```

**设计理念**
- 锁定比例越低，增长奖励越高
- 激励用户锁定代币获取投票权
- 平衡流动性和治理参与度

#### 5. 尾部发行调整

**Nudge 机制**
```solidity
function nudge() external {
    address _epochGovernor = voter.epochGovernor();
    if (msg.sender != _epochGovernor) revert NotEpochGovernor();
    
    IEpochGovernor.ProposalState _state = IEpochGovernor(_epochGovernor).result();
    if (weekly >= TAIL_START) revert TailEmissionsInactive();
    
    uint256 _newRate = tailEmissionRate;
    uint256 _oldRate = _newRate;
    
    if (_state == IEpochGovernor.ProposalState.Succeeded) {
        // 提案通过：增加发行率
        _newRate = _oldRate + NUDGE > MAXIMUM_TAIL_RATE ? MAXIMUM_TAIL_RATE : _oldRate + NUDGE;
    } else {
        // 提案失败：降低发行率
        _newRate = _oldRate - NUDGE < MINIMUM_TAIL_RATE ? MINIMUM_TAIL_RATE : _oldRate - NUDGE;
    }
    
    tailEmissionRate = _newRate;
    proposals[activePeriod] = true;
}
```

### 初始化和分配

#### 1. 空投初始化
```solidity
struct AirdropParams {
    address[] liquidWallets;
    uint256[] liquidAmounts;
    address[] lockedWallets;
    uint256[] lockedAmounts;
}

function initialize(AirdropParams memory params) external {
    if (initialized) revert AlreadyInitialized();
    if (msg.sender != team) revert NotTeam();
    
    // 分发流动代币
    for (uint256 i = 0; i < params.liquidWallets.length; i++) {
        aero.mint(params.liquidWallets[i], params.liquidAmounts[i]);
    }
    
    // 创建锁定 NFT
    for (uint256 i = 0; i < params.lockedWallets.length; i++) {
        uint256 _tokenId = ve.createLock(params.lockedAmounts[i], WEEK);
        ve.lockPermanent(_tokenId); // 永久锁定
        ve.safeTransferFrom(address(this), params.lockedWallets[i], _tokenId);
    }
}
```

### 治理功能

#### 团队管理
```solidity
function setTeam(address _team) external {
    if (msg.sender != team) revert NotTeam();
    pendingTeam = _team;
}

function acceptTeam() external {
    if (msg.sender != pendingTeam) revert NotPendingTeam();
    team = pendingTeam;
    delete pendingTeam;
}
```

## 7. Gauge.sol - 流动性挖矿合约

### 合约概述
`Gauge.sol` 是流动性挖矿的核心合约，负责分发 AERO 代币奖励给 LP 代币质押者。

### 核心机制

#### 1. 奖励计算模型

**奖励率存储**
```solidity
uint256 public rewardRate;                    // 每秒奖励率
uint256 public periodFinish;                  // 奖励期结束时间
uint256 public lastUpdateTime;                // 最后更新时间
uint256 public rewardPerTokenStored;          // 累积每代币奖励
mapping(address => uint256) public userRewardPerTokenPaid; // 用户已支付奖励
mapping(address => uint256) public rewards;   // 用户待领取奖励
```

**每代币奖励计算**
```solidity
function rewardPerToken() public view returns (uint256) {
    if (totalSupply == 0) {
        return rewardPerTokenStored;
    }
    return rewardPerTokenStored + 
           (lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * PRECISION / totalSupply;
}
```

**用户奖励计算**
```solidity
function earned(address account) public view returns (uint256) {
    return balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / PRECISION + rewards[account];
}
```

#### 2. 质押和提取

**质押 LP 代币**
```solidity
function deposit(uint256 amount) external nonReentrant updateReward(msg.sender) {
    if (amount == 0) revert ZeroAmount();
    
    _claimFees(); // 领取池子费用
    
    totalSupply += amount;
    balanceOf[msg.sender] += amount;
    
    IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), amount);
    emit Deposit(msg.sender, amount);
}
```

**提取 LP 代币**
```solidity
function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
    if (amount == 0) revert ZeroAmount();
    
    totalSupply -= amount;
    balanceOf[msg.sender] -= amount;
    
    IERC20(stakingToken).safeTransfer(msg.sender, amount);
    emit Withdraw(msg.sender, amount);
}
```

#### 3. 奖励分发

**通知奖励数量**
```solidity
function notifyRewardAmount(uint256 amount) external updateReward(address(0)) {
    if (msg.sender != voter) revert NotVoter();
    
    IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amount);
    
    uint256 _periodFinish = periodFinish;
    if (block.timestamp >= _periodFinish) {
        // 新周期开始
        rewardRate = amount / DURATION;
    } else {
        // 周期内追加奖励
        uint256 remaining = _periodFinish - block.timestamp;
        uint256 leftover = remaining * rewardRate;
        rewardRate = (amount + leftover) / DURATION;
    }
    
    lastUpdateTime = block.timestamp;
    periodFinish = block.timestamp + DURATION;
    rewardRateByEpoch[ProtocolTimeLibrary.epochStart(block.timestamp)] = rewardRate;
}
```

#### 4. 费用处理

**池子费用领取**
```solidity
function _claimFees() internal returns (uint256 claimed0, uint256 claimed1) {
    if (!isPool) return (0, 0);
    
    address _token0 = IPool(stakingToken).token0();
    address _token1 = IPool(stakingToken).token1();
    
    (claimed0, claimed1) = IPool(stakingToken).claimFees();
    
    if (claimed0 > 0 || claimed1 > 0) {
        uint256 _fees0 = fees0 + claimed0;
        uint256 _fees1 = fees1 + claimed1;
        
        (fees0, fees1) = (0, 0);
        
        // 转移费用到投票奖励合约
        IERC20(_token0).safeTransfer(feesVotingReward, _fees0);
        IERC20(_token1).safeTransfer(feesVotingReward, _fees1);
        
        IReward(feesVotingReward).notifyRewardAmount(_token0, _fees0);
        IReward(feesVotingReward).notifyRewardAmount(_token1, _fees1);
    }
}
```

### 修饰器和安全机制

#### 1. 奖励更新修饰器
```solidity
modifier updateReward(address account) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = lastTimeRewardApplicable();
    
    if (account != address(0)) {
        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
    _;
}
```

#### 2. 重入保护
所有状态变更函数都使用 `nonReentrant` 修饰器防止重入攻击。

#### 3. 精度处理
使用 `PRECISION = 10^18` 确保奖励计算的精度。

## 总结

### 架构优势

1. **模块化设计**: 每个合约职责单一，便于升级和维护
2. **安全性**: 多层安全机制，包括重入保护、权限控制、溢出保护
3. **经济激励**: 精心设计的代币经济学模型平衡各方利益
4. **可扩展性**: 工厂模式支持协议持续演进
5. **用户体验**: Router 简化复杂操作，支持一键操作

### 创新特性

1. **双池模型**: 同时支持稳定币和波动性代币交易
2. **veTokenomics**: 时间锁定投票权重模型
3. **托管 NFT**: 专业化的投票权管理
4. **动态发行**: 根据锁定比例调整发行策略
5. **费用分配**: 精细化的费用分配机制

### 风险考虑

1. **智能合约风险**: 代码复杂性带来的潜在漏洞
2. **经济攻击**: 大户操纵投票和奖励分配
3. **治理风险**: 中心化治理决策的风险
4. **市场风险**: 代币价格波动影响激励效果

Aerodrome 协议通过精心设计的合约架构和经济机制，为 DeFi 生态系统提供了一个功能完善、安全可靠的 AMM 解决方案。