// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";

import {FundMe, NotOwner} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {Constant} from "../../src/global/Constant.sol";

contract FundMeTest is Test {
    uint256 constant GAS_PRICE = 1;
    address alice = makeAddr("alice");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 favNumber = 0;
    bool greatCourse = false;
    FundMe fundMe;
    DeployFundMe deployFundMe;

    function setUp() external {
        // Print the balance of the accout msg.sender
        //console.log("[*] msg.sender.balance #0: ", msg.sender.balance);

        //fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();

        // Set account balance for account "alice"
        vm.deal(alice, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        if (block.chainid == 1) {
            assertEq(version, 6);
        } else {
            assertEq(version, 4);
        }
    }

    function testGetPriceFundMeForAnvilChain() public view {
        uint256 price = fundMe.getPriceFundMe();
        if (block.chainid == Constant.ANVIL_CHAIN_ID) {
            assertEq(price, 2000e8 * 1e10); // 2000000000000000000000 = 2e21 = 2000 * 1e18 = 2000e18
        }
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert("You need to spend more ETH!");
        fundMe.fund();
    }

    function testFundUpdatesFundDataStructure() public aliceFunded {
        uint256 ammountFunded = fundMe.getAddressToAmountFunded(alice);
        assertEq(ammountFunded, SEND_VALUE);
    }

    function testFundersUpdate() public aliceFunded {
        // Get amount of funders to know the index of the last funder
        address funder = fundMe.getFunder(0); // The newly added funder's index is (current last index) is the "fundersAmount" AFTER fund()
        assertEq(funder, alice);
    }

    function testGetFunderAmount() public aliceFunded {
        uint256 fundersAmount = fundMe.getFundersAmount();
        assertEq(fundersAmount, 1);
    }

    function testGetPriceFundMe() public view {
        uint256 price = fundMe.getPriceFundMe();
        if (block.chainid == Constant.ANVIL_CHAIN_ID) {
            assertEq(price, 2000e18);
        } else {
            assertGt(price, 1500e18);
        }
    }

    function testReceive() public {
        // Get the current balance of the contract
        uint256 contractBalanceBefore = address(fundMe).balance;
        // Make alice become msg.sender of the next call
        vm.prank(alice);
        // Call the contract without sending any data, but sending some value
        (bool success, ) = address(fundMe).call{value: SEND_VALUE}("");
        // Make sure the call is successful
        assertTrue(success);
        // Make sure the contract balance received the value
        uint256 contractBalanceAfter = address(fundMe).balance;
        assertEq(contractBalanceAfter, contractBalanceBefore + SEND_VALUE);
    }

    function testFallback() public {
        // Get the current balance of the contract
        uint256 contractBalanceBefore = address(fundMe).balance;
        // Make alice become msg.sender of the next call
        vm.prank(alice);
        // Call the contract, sending invalid data, and sending some value
        (bool success, ) = address(fundMe).call{value: SEND_VALUE}(
            "this is the invalid data"
        );
        // Make sure the call is successful
        assertTrue(success);
        // Make sure the contract balance received the value
        uint256 contractBalanceAfter = address(fundMe).balance;
        assertEq(contractBalanceAfter, contractBalanceBefore + SEND_VALUE);
    }

    function testGetOwner() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    modifier aliceFunded() {
        vm.prank(alice);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    /* All withdraw test: start */

    function testWithDrawFromOwner() public aliceFunded {
        // Arrange
        uint256 fundMeBalanceBefore = address(fundMe).balance;
        uint256 msgSenderBalanceBefore = msg.sender.balance;

        vm.txGasPrice(GAS_PRICE); // Set the gas price
        uint256 gasStart = gasleft(); // Get the gas left before the withdraw()

        // Act
        vm.startPrank(msg.sender); // Set this account to be the owner before withdraw()
        fundMe.withdraw(); // Withdraw all the funds to the owner
        vm.stopPrank(); // Reset the owner to the original owner

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; // Calculate the gas used
        console.log("[*] Gas start: ", gasStart);
        console.log("[*] Gas end  : ", gasEnd);
        console.log("[*] Gas used : ", gasUsed);
        console.log("[*] Gas price: ", tx.gasprice);

        // Assert
        uint256 msgSenderBalanceAfter = msg.sender.balance;
        uint256 fundMeBalanceAfter = address(fundMe).balance;
        // Make sure the fundMeBalanceAfter = 0
        assertEq(fundMeBalanceAfter, 0 ether);
        // Make sure the msgSenderBalanceAfter = msgSenderBalanceBefore + fundMeBalanceBefore
        assertEq(
            msgSenderBalanceAfter,
            msgSenderBalanceBefore + fundMeBalanceBefore
        );
    }

    function testWithDrawNotFromOwner() public aliceFunded {
        assertEq(address(deployFundMe).balance, 0 ether);
        vm.prank(address(0x0)); // Set this account to be the invalid account before withdraw()
        vm.expectRevert(NotOwner.selector);
        fundMe.withdraw(); // This function should revert
    }

    function testWithdrawCallFails() public aliceFunded {
        // Simulate a scenario where the call to the fallback function fails
        address fundMeOwner = fundMe.getOwner();
        vm.prank(fundMeOwner); // Set the owner as the sender
        bytes memory emptyDataBytes = "";
        vm.mockCallRevert(
            fundMeOwner, // Mock the call to the owner's fallback function
            emptyDataBytes, // calldata — "" means fallback or receive
            emptyDataBytes // empty revert data
        );

        vm.expectRevert("Call failed");
        fundMe.withdraw();
    }

    function testWithdrawFromMultipleFunders() public {
        uint160 numberOfFunders = 100;
        uint160 startingFunderIndex = 1;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        assertEq(address(fundMe).balance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            fundMe.getOwner().balance
        );
        assertEq(
            (numberOfFunders) * SEND_VALUE,
            fundMe.getOwner().balance - startingOwnerBalance
        );
    }

    /* All withdraw test: end */

    /* All cheaper withdraw test: start */

    function testWithDrawFromOwnerCheaper() public aliceFunded {
        // Arrange
        uint256 fundMeBalanceBefore = address(fundMe).balance;
        uint256 msgSenderBalanceBefore = msg.sender.balance;

        vm.txGasPrice(GAS_PRICE); // Set the gas price
        uint256 gasStart = gasleft(); // Get the gas left before the withdraw()

        // Act
        vm.startPrank(msg.sender); // Set this account to be the owner before withdraw()
        fundMe.cheaperWithdraw(); // Withdraw all the funds to the owner
        vm.stopPrank(); // Reset the owner to the original owner

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; // Calculate the gas used
        console.log("[*] Gas start: ", gasStart);
        console.log("[*] Gas end  : ", gasEnd);
        console.log("[*] Gas used : ", gasUsed);
        console.log("[*] Gas price: ", tx.gasprice);

        // Assert
        uint256 msgSenderBalanceAfter = msg.sender.balance;
        uint256 fundMeBalanceAfter = address(fundMe).balance;
        // Make sure the fundMeBalanceAfter = 0
        assertEq(fundMeBalanceAfter, 0 ether);
        // Make sure the msgSenderBalanceAfter = msgSenderBalanceBefore + fundMeBalanceBefore
        assertEq(
            msgSenderBalanceAfter,
            msgSenderBalanceBefore + fundMeBalanceBefore
        );
    }

    function testWithDrawNotFromOwnerCheaper() public aliceFunded {
        assertEq(address(deployFundMe).balance, 0 ether);
        vm.prank(address(0x0)); // Set this account to be the invalid account before withdraw()
        vm.expectRevert(NotOwner.selector);
        fundMe.cheaperWithdraw(); // This function should revert
    }

    function testWithdrawCallFailsCheaper() public aliceFunded {
        // Simulate a scenario where the call to the fallback function fails
        address fundMeOwner = fundMe.getOwner();
        vm.prank(fundMeOwner); // Set the owner as the sender
        bytes memory emptyDataBytes = "";
        vm.mockCallRevert(
            fundMeOwner, // Mock the call to the owner's fallback function
            emptyDataBytes, // calldata — "" means fallback or receive
            emptyDataBytes // empty revert data
        );

        vm.expectRevert("Call failed");
        fundMe.cheaperWithdraw();
    }

    function testWithdrawFromMultipleFundersCheaper() public {
        uint160 numberOfFunders = 100;
        uint160 startingFunderIndex = 1;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        assertEq(address(fundMe).balance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            fundMe.getOwner().balance
        );
        assertEq(
            (numberOfFunders) * SEND_VALUE,
            fundMe.getOwner().balance - startingOwnerBalance
        );
    }

    /* All cheaper withdraw test: end */

    function testPrintStorageData() public view {
        for (uint256 i = 0; i < 3; i++) {
            bytes32 value = vm.load(address(fundMe), bytes32(i));
            console.log("[*] Value at location", i, ":");
            console.logBytes32(value);
        }
        console.log("[*] PriceFeed address:", address(fundMe.getPriceFeed()));
    }
}
