// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {FundFundMe, WithdrawFundMe} from "../../script/Interactions.s.sol";
import {FundMe} from "../../src/FundMe.sol";
import {Test, console} from "forge-std/Test.sol";

contract InteractionsTest is Test {
    FundMe public fundMe;
    DeployFundMe deployFundMe;

    uint256 public constant SEND_VALUE = 0.1 ether;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    address alice = makeAddr("alice");

    function setUp() external {
        deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(alice, STARTING_USER_BALANCE);
    }

    function testUserCanFundInteractions() public {
        FundFundMe fundFundMe = new FundFundMe(); // Why we not use FundFundMe?
        fundFundMe.fundFundMe(address(fundMe));

        assertEq(address(fundMe).balance, SEND_VALUE);
        assertEq(fundMe.getFunder(0), msg.sender);
    }

    function testOwnerFundInteractionsAndOwnerWithdrawInteractions() public {
        uint256 preOwnerBalance = msg.sender.balance;

        FundFundMe fundFundMe = new FundFundMe();
        fundFundMe.fundFundMe(address(fundMe));

        uint256 afterFundOwnerBalance = msg.sender.balance;

        WithdrawFundMe withdrawFundMe = new WithdrawFundMe();
        withdrawFundMe.withdrawFundMe(address(fundMe));

        uint256 afterWithdrawOwnerBalance = msg.sender.balance;

        assert(address(fundMe).balance == 0);
        assertEq(preOwnerBalance - SEND_VALUE, afterFundOwnerBalance);
        assertEq(preOwnerBalance, afterWithdrawOwnerBalance);
    }

    function testAliceFundAndOwnerWithdrawInteractions() public {
        uint256 preUserBalance = address(alice).balance;
        uint256 preOwnerBalance = address(fundMe.getOwner()).balance;

        // Using vm.prank to simulate funding from the USER address
        vm.prank(alice);
        fundMe.fund{value: SEND_VALUE}();
        //FundFundMe fundFundMe = new FundFundMe(); // Why we not use FundFundMe?
        //fundFundMe.fundFundMe(address(fundMe));

        WithdrawFundMe withdrawFundMe = new WithdrawFundMe();
        withdrawFundMe.withdrawFundMe(address(fundMe));

        uint256 afterUserBalance = address(alice).balance;
        uint256 afterOwnerBalance = address(fundMe.getOwner()).balance;

        assert(address(fundMe).balance == 0);
        assertEq(afterUserBalance + SEND_VALUE, preUserBalance);
        assertEq(preOwnerBalance + SEND_VALUE, afterOwnerBalance);
    }
}
