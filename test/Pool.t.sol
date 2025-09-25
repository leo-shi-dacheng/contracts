// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {DexTestBase} from "./utils/DexTestBase.sol";
import {Pool} from "contracts/Pool.sol";
import {MockERC20} from "./utils/MockERC20.sol";

contract PoolTest is DexTestBase {
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    Pool internal pool;

    function setUp() public override {
        super.setUp();

        tokenA = _createMockToken("Token A", "TKA", 18);
        tokenB = _createMockToken("Token B", "TKB", 18);
        pool = _createPool(address(tokenA), address(tokenB), false);

        _deal(address(tokenA), address(this), 1_000 ether);
        _deal(address(tokenB), address(this), 1_000 ether);
    }

    function _provideInitialLiquidity(uint256 amountA, uint256 amountB) internal returns (uint256 liquidity) {
        tokenA.transfer(address(pool), amountA);
        tokenB.transfer(address(pool), amountB);
        liquidity = pool.mint(address(this));
    }

    function testMintAndBurn() public {
        uint256 liquidity = _provideInitialLiquidity(100 ether, 100 ether);
        assertGt(liquidity, 0);

        pool.transfer(address(pool), liquidity);
        (uint256 amount0, uint256 amount1) = pool.burn(address(this));

        assertApproxEqAbs(amount0, 100 ether, 1e9);
        assertApproxEqAbs(amount1, 100 ether, 1e9);
    }

    function testSwapUpdatesReserves() public {
        _provideInitialLiquidity(100 ether, 100 ether);

        uint256 amountIn = 10 ether;
        uint256 expectedOut = pool.getAmountOut(amountIn, address(tokenA));

        (address token0, ) = pool.tokens();
        bool tokenAIsToken0 = address(tokenA) == token0;

        uint256 balanceBBefore = tokenB.balanceOf(address(this));
        tokenA.transfer(address(pool), amountIn);
        if (tokenAIsToken0) {
            pool.swap(0, expectedOut, address(this), new bytes(0));
        } else {
            pool.swap(expectedOut, 0, address(this), new bytes(0));
        }

        uint256 expectedBalanceB = balanceBBefore + expectedOut;
        assertEq(tokenB.balanceOf(address(this)), expectedBalanceB);

        (uint256 reserve0, uint256 reserve1, ) = pool.getReserves();
        uint256 reserveA = tokenAIsToken0 ? reserve0 : reserve1;
        uint256 reserveB = tokenAIsToken0 ? reserve1 : reserve0;

        assertEq(reserveA, tokenA.balanceOf(address(pool)));
        assertEq(reserveB, tokenB.balanceOf(address(pool)));
        assertGt(reserveA, 100 ether);
        assertLt(reserveB, 100 ether);
    }

    function testClaimFeesAccumulates() public {
        _provideInitialLiquidity(100 ether, 100 ether);

        tokenA.transfer(address(pool), 10 ether);
        uint256 out = pool.getAmountOut(10 ether, address(tokenA));
        (address token0, ) = pool.tokens();
        if (address(tokenA) == token0) {
            pool.swap(0, out, address(this), new bytes(0));
        } else {
            pool.swap(out, 0, address(this), new bytes(0));
        }

        (uint256 claim0, uint256 claim1) = pool.claimFees();
        assertTrue(claim0 > 0 || claim1 > 0);
    }

    function testSetMetadataFromPauser() public {
        _provideInitialLiquidity(100 ether, 100 ether);
        pool.setName("Volatile Pool");
        pool.setSymbol("vPOOL");
        assertEq(pool.name(), "Volatile Pool");
        assertEq(pool.symbol(), "vPOOL");
    }
}
