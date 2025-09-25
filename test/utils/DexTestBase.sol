// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {ProtocolForwarder} from "contracts/ProtocolForwarder.sol";
import {Pool} from "contracts/Pool.sol";
import {PoolFactory} from "contracts/factories/PoolFactory.sol";
import {Router} from "contracts/Router.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockWHSK} from "./MockWHSK.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DexTestBase is Test {
    ProtocolForwarder internal forwarder;
    Pool internal implementation;
    PoolFactory internal factory;
    Router internal router;
    MockWHSK internal whsk;

    address internal deployer;

    receive() external payable {}

    function setUp() public virtual {
        deployer = address(this);
        forwarder = new ProtocolForwarder();
        implementation = new Pool();
        factory = new PoolFactory(address(implementation));
        whsk = new MockWHSK();
        router = new Router(address(forwarder), address(factory), address(whsk));
    }

    function _createMockToken(string memory name, string memory symbol, uint8 decimals)
        internal
        returns (MockERC20 token)
    {
        token = new MockERC20(name, symbol, decimals);
    }

    function _createPool(address tokenA, address tokenB, bool stable) internal returns (Pool pool) {
        address poolAddr = factory.createPool(tokenA, tokenB, stable);
        pool = Pool(poolAddr);
    }

    function _deal(address token, address to, uint256 amount) internal {
        deal(token, to, amount, true);
    }

    function _addLiquidity(
        Pool pool,
        address tokenA,
        address tokenB,
        address provider,
        uint256 amountA,
        uint256 amountB
    ) internal returns (uint256 liquidity) {
        vm.startPrank(provider);
        IERC20(tokenA).transfer(address(pool), amountA);
        IERC20(tokenB).transfer(address(pool), amountB);
        liquidity = pool.mint(provider);
        vm.stopPrank();
    }

    function _routerAddLiquidity(
        address provider,
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountA,
        uint256 amountB
    ) internal returns (uint256 liquidity) {
        vm.startPrank(provider);
        IERC20(tokenA).approve(address(router), amountA);
        IERC20(tokenB).approve(address(router), amountB);
        (, , liquidity) = router.addLiquidity(
            tokenA,
            tokenB,
            stable,
            amountA,
            amountB,
            0,
            0,
            provider,
            block.timestamp
        );
        vm.stopPrank();
    }

    function _routerAddLiquidityHSK(
        address provider,
        address token,
        bool stable,
        uint256 amountToken,
        uint256 amountHSK
    ) internal returns (uint256 liquidity) {
        vm.startPrank(provider);
        IERC20(token).approve(address(router), amountToken);
        (, , liquidity) = router.addLiquidityHSK{value: amountHSK}(
            token,
            stable,
            amountToken,
            0,
            0,
            provider,
            block.timestamp
        );
        vm.stopPrank();
    }
}
