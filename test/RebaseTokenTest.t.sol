// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "../lib/forge-std/src/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRabaseToken.sol";
contract RebaseTokenTest is Test {

    RebaseToken private rebaseToken;
    Vault private vault;

    address private OWNER = makeAddr("OWNER");
    address private USER = makeAddr("USER");

    function setUp() public {
        vm.startPrank(OWNER);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }
    
    function addRewardToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value:rewardAmount}(""); 
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5,type(uint96).max);
        vm.startPrank(USER);
        vm.deal(USER, amount);
        vault.deposit{value:amount}();
        uint256 startBalance = rebaseToken.balanceOf(USER);
        assertEq(startBalance, amount);
        vm.warp(block.timestamp + 1 hours);
        uint256 midBalance = rebaseToken.balanceOf(USER);
        assertGt(midBalance, startBalance);
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(USER);
        assertGt(endBalance, midBalance);
        assertApproxEqAbs(endBalance - midBalance, midBalance - startBalance,1 );
        vm.stopPrank();
    }
    function testRedeemDirectly(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // Deposit funds
        vm.startPrank(USER);
        vm.deal(USER, amount);
        vault.deposit{value: amount}();

        // Redeem funds
        vault.redeem(amount);

        uint256 balance = rebaseToken.balanceOf(USER);
        // console.log("User balance: %d", balance);
        assertEq(balance, 0);
        vm.stopPrank();
    }


    function testRedeemAfterSomeTime(uint256 amount, uint256 time) public {
        amount = bound(amount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint96).max);

        vm.prank(USER);
        vm.deal(USER, amount);
        vault.deposit{value:amount}();

        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(USER);
        
        vm.deal(OWNER, balanceAfterSomeTime - amount);
        vm.prank(OWNER);
        addRewardToVault(balanceAfterSomeTime - amount);

        vm.prank(USER);
        vault.redeem(type(uint256).max); 
        uint256 ethBalance = address(USER).balance;
        
        assertEq(balanceAfterSomeTime, ethBalance);
        assertGt(ethBalance, amount);

    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
        vm.prank(USER);
        vm.deal(USER, amount);
        vault.deposit{value:amount}();

        address USER2 = makeAddr("USER2");
        uint256 userBalance = rebaseToken.balanceOf(USER);
        uint256 user2Balance = rebaseToken.balanceOf(USER2);
        assertEq(userBalance, amount);
        assertEq(address(USER).balance, 0);
        assertEq(user2Balance, 0);

        vm.prank(OWNER);
        rebaseToken.setInterestRate(4e10);

        vm.prank(USER);
        rebaseToken.transfer(USER2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(USER);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(USER2);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        assertEq(rebaseToken.getUserInterestRate(USER2), 5e10);
        assertEq(rebaseToken.getUserInterestRate(USER ), 5e10);
    }
    function testCannotSetInterestRateIfNotOwner(uint256 newInterestRate) public {
        // newInterestRate = bound(newInterestRate, 1e10, type(uint8).max);
        vm.prank(USER);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
    }
    function testCannotCallMintIfNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        rebaseToken.mint(USER, 100, rebaseToken.getInterestRate());
    }
    function testCannotCallBurnIfNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        rebaseToken.burn(USER, 100);
    }
    function testGetPrincipleAmount(uint256 amount) public {
        vm.deal(USER, amount);
        vm.prank(USER);
        vault.deposit{value:amount}();
        assertEq(rebaseToken.principleBalanceOf(USER), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(USER), amount);
    }
    function getRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }
    function testInterestRateOnlyDecrease(uint256 interestRate) public {
        interestRate = bound(interestRate, rebaseToken.getInterestRate(), type(uint96).max);
        vm.prank(OWNER);
        vm.expectRevert();
        rebaseToken.setInterestRate(interestRate);
    }   
}