// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {DexTestBase} from "./utils/DexTestBase.sol";
import {IPoolFactory} from "contracts/interfaces/factories/IPoolFactory.sol";
import {Pool} from "contracts/Pool.sol";
import {MockERC20} from "./utils/MockERC20.sol";

contract PoolFactoryTest is DexTestBase {
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;

    function setUp() public override {
        super.setUp();
        tokenA = _createMockToken("Token A", "TKA", 18);
        tokenB = _createMockToken("Token B", "TKB", 18);
    }

    function testCreatePoolDeterministic() public {
        address first = factory.createPool(address(tokenA), address(tokenB), false);
        address second = factory.getPool(address(tokenA), address(tokenB), false);
        assertEq(first, second);

        address stableFirst = factory.createPool(address(tokenA), address(tokenB), true);
        address stableSecond = factory.getPool(address(tokenA), address(tokenB), true);
        assertEq(stableFirst, stableSecond);

        assertTrue(factory.isPool(first));
        assertTrue(factory.isPool(stableFirst));
    }

    function testCannotCreateDuplicatePool() public {
        factory.createPool(address(tokenA), address(tokenB), false);
        vm.expectRevert(IPoolFactory.PoolAlreadyExists.selector);
        factory.createPool(address(tokenA), address(tokenB), false);
    }

    function testSetCustomFee() public {
        address poolAddr = factory.createPool(address(tokenA), address(tokenB), false);
        factory.setCustomFee(poolAddr, 50);
        assertEq(factory.customFee(poolAddr), 50);

        vm.expectRevert(IPoolFactory.FeeTooHigh.selector);
        factory.setCustomFee(poolAddr, 1_000);
    }

    function testSetters() public {
        address newPauser = address(0xBEEF);
        factory.setPauser(newPauser);
        assertEq(factory.pauser(), newPauser);

        vm.prank(newPauser);
        factory.setPauseState(true);
        assertTrue(factory.isPaused());

        address newFeeManager = address(0xFEED);
        factory.setFeeManager(newFeeManager);
        assertEq(factory.feeManager(), newFeeManager);

        vm.prank(newFeeManager);
        factory.setFee(false, 100);
        assertEq(factory.volatileFee(), 100);
    }

    function testCreatePoolWithCreate2MatchesRouterPrediction() public {
        address poolAddr = factory.createPool(address(tokenA), address(tokenB), false);
        Pool pool = Pool(poolAddr);
        (address t0, address t1) = pool.tokens();
        assertTrue(t0 < t1);
    }
}
