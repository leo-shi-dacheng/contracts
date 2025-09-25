// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {DexTestBase} from "./utils/DexTestBase.sol";
import {IRouter} from "contracts/interfaces/IRouter.sol";
import {MockERC20} from "./utils/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RouterTest is DexTestBase {
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;

    function setUp() public override {
        super.setUp();
        tokenA = _createMockToken("Token A", "TKA", 18);
        tokenB = _createMockToken("Token B", "TKB", 18);

        _deal(address(tokenA), address(this), 10_000 ether);
        _deal(address(tokenB), address(this), 10_000 ether);
    }

    function _defaultRoute(bool stable)
        internal
        view
        returns (IRouter.Route[] memory routes)
    {
        routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({from: address(tokenA), to: address(tokenB), stable: stable, factory: address(0)});
    }

    function testAddAndRemoveLiquidity() public {
        IRouter.Route[] memory routes = _defaultRoute(false);

        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);

        (, , uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            false,
            1_000 ether,
            1_000 ether,
            0,
            0,
            address(this),
            block.timestamp
        );
        assertGt(liquidity, 0);

        address poolAddr = factory.getPool(address(tokenA), address(tokenB), false);
        routes = _defaultRoute(false);
        uint256[] memory amounts = router.swapExactTokensForTokens(
            100 ether,
            0,
            routes,
            address(this),
            block.timestamp
        );
        assertEq(amounts[0], 100 ether);
        assertGt(amounts[1], 0);

        uint256 lpBalance = IERC20(poolAddr).balanceOf(address(this));
        IERC20(poolAddr).approve(address(router), lpBalance);
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            false,
            lpBalance,
            0,
            0,
            address(this),
            block.timestamp
        );
        assertGt(amountA, 0);
        assertGt(amountB, 0);
    }

    function testAddLiquidityHSKAndSwap() public {
        vm.deal(address(this), 1_000 ether);

        tokenA.approve(address(router), type(uint256).max);

        (, , uint256 liquidity) = router.addLiquidityHSK{value: 200 ether}(
            address(tokenA),
            false,
            200 ether,
            0,
            0,
            address(this),
            block.timestamp
        );
        assertGt(liquidity, 0);

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({from: address(whsk), to: address(tokenA), stable: false, factory: address(0)});

        router.swapExactHSKForTokensSupportingFeeOnTransferTokens{value: 10 ether}(
            0,
            routes,
            address(this),
            block.timestamp
        );

        // swap tokens for HSK
        routes[0] = IRouter.Route({from: address(tokenA), to: address(whsk), stable: false, factory: address(0)});
        _deal(address(tokenA), address(this), 100 ether);
        tokenA.approve(address(router), type(uint256).max);
        router.swapExactTokensForHSKSupportingFeeOnTransferTokens(
            50 ether,
            0,
            routes,
            address(this),
            block.timestamp
        );
    }

    function testPoolForMatchesFactory() public {
        address predicted = router.poolFor(address(tokenA), address(tokenB), false, address(0));
        address actual = factory.createPool(address(tokenA), address(tokenB), false);
        assertEq(predicted, actual);
    }
}
