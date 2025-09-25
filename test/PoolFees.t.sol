// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {DexTestBase} from "./utils/DexTestBase.sol";
import {Pool} from "contracts/Pool.sol";
import {PoolFees} from "contracts/PoolFees.sol";
import {MockERC20} from "./utils/MockERC20.sol";

contract PoolFeesTest is DexTestBase {
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

        tokenA.transfer(address(pool), 100 ether);
        tokenB.transfer(address(pool), 100 ether);
        pool.mint(address(this));
    }

    function testFeesAccumulateInPoolFees() public {
        tokenA.transfer(address(pool), 10 ether);
        uint256 out = pool.getAmountOut(10 ether, address(tokenA));
        (address token0, address token1) = pool.tokens();
        if (address(tokenA) == token0) {
            pool.swap(0, out, address(this), new bytes(0));
        } else {
            pool.swap(out, 0, address(this), new bytes(0));
        }

        PoolFees fees = PoolFees(pool.poolFees());
        assertEq(fees.poolAddress(), address(pool));
        assertEq(fees.token0Address(), token0);
        assertEq(fees.token1Address(), token1);

        uint256 balance0Before = tokenA.balanceOf(address(this));
        uint256 balance1Before = tokenB.balanceOf(address(this));
        (uint256 claim0, uint256 claim1) = pool.claimFees();
        bool tokenAIsToken0 = address(tokenA) == token0;
        uint256 claimForTokenA = tokenAIsToken0 ? claim0 : claim1;
        uint256 claimForTokenB = tokenAIsToken0 ? claim1 : claim0;

        assertEq(tokenA.balanceOf(address(this)), balance0Before + claimForTokenA);
        assertEq(tokenB.balanceOf(address(this)), balance1Before + claimForTokenB);
    }
}
