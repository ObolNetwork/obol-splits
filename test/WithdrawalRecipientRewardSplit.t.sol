// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/WithdrawalRecipientRewardSplit.sol";
import "src/SplitMain.sol"; // 0xSplits
import 'solmate/tokens/ERC20.sol'; // 0xSplits function input param dependency

/// @title Tests for WithdrawalRecipientRewardSplit 
/// @author 0xArbiter on behalf of Obol Labs
/// @dev My forge-std hoax and other cheatcodes were not working hence the prank and deal usage
contract WithdrawalRecipientRewardSplitTest is Test {
    
    WithdrawalRecipientRewardSplit wrapper;
    SplitMain splitter;

    // You can change this as you see fit
    address constant beneficiaryAddress = address(0xbe4Ef1C1A4EE0000000000000000000000000000);
    address constant deterministicSplitterAddress = address(0x7F9c98f308C652E252B8b2B01af1F6d35E8bCd5f);
    
    // Constants needed for the uint256 to string workaround
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    receive() payable external{}

    /// @dev Setup Tests
    function setUp() public {
        
        address deployerAddress_ = beneficiaryAddress;
        // Restrict the address for beneficiary
        _fuzzTestRestrictions(deployerAddress_);

        vm.startPrank(deployerAddress_); 

        // Set up the splitter 
        splitter = new SplitMain();

        // Set up the wrapper, passing in the splitter address
        wrapper = new WithdrawalRecipientRewardSplit(deterministicSplitterAddress, splitter);

        vm.stopPrank(); 
        
    }

    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /// @dev This is the best way to convert a uint to string in 2022...
    function _toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /// @dev helper for other tests. Excludes particular addresses from fuzzing.
    function _fuzzTestRestrictions(address fuzzAddress_) internal {
        vm.assume(fuzzAddress_ != address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D)); // VM address
        vm.assume(fuzzAddress_ != address(0xCe71065D4017F316EC606Fe4422e11eB2c47c246)); // Fuzzer Dict
        vm.assume(fuzzAddress_ != address(0x4e59b44847b379578588920cA78FbF26c0B4956C)); // Create2 Precompile Address
        vm.assume(fuzzAddress_ != address(0x000000000000000000636F6e736F6c652e6c6f67)); // Console address
        vm.assume(fuzzAddress_ != address(0x00a329c0648769A73afAc7F9381E08FB43dBEA72)); // Parity recovery address
        vm.assume(fuzzAddress_ != address(0x0000000000000000000000000000000000000009)); // Precompile Address
        vm.assume(fuzzAddress_ != address(0x0000000000000000000000000000000000000008)); // Precompile Address
        vm.assume(fuzzAddress_ != address(0x0000000000000000000000000000000000000004)); // Precompile Address
        vm.assume(fuzzAddress_ != address(0x0000000000000000000000000000000000000001)); // Precompile Address
        vm.assume(fuzzAddress_ != address(0x0000000000000000000000000000000000000000)); // Zero Address
        vm.assume(fuzzAddress_ != address(this)); // This contract
        vm.assume(address(fuzzAddress_).balance == 0); // Ignore non-zero recipients because it breaks our math
    }


    /// @dev Helper for calculating an array sum taken from 0xSplits contract
    function _getSum(uint32[] memory numbers) internal pure returns (uint32 sum) {
        // overflow should be impossible in for-loop index
        uint256 numbersLength = numbers.length;
        for (uint256 i = 0; i < numbersLength; ) {
        sum += numbers[i];
        unchecked {
            // overflow should be impossible in for-loop index
            ++i;
        }
        }
    }

    /// @dev Helper for calculating multiplication taken from 0xSplits contract
    function _scaleAmountByPercentage(uint256 amount, uint256 scaledPercent)
        internal
        pure
        returns (uint256 scaledAmount)
    {
        // use assembly to bypass checking for overflow & division by 0
        // scaledPercent has been validated to be < PERCENTAGE_SCALE)
        // & PERCENTAGE_SCALE will never be 0
        // pernicious ERC20s may cause overflow, but results do not affect ETH & other ERC20 balances
        assembly {
        /* eg (100 * 2*1e4) / (1e6) */
        scaledAmount := div(mul(amount, scaledPercent), 1000000)
        }
    }

    
    // Test withdrawEther success case by withdrawing two times in a row
    function testWithdrawEtherSuccessCases(uint256 firstAmountToWithdraw_, uint256 secondAmountToWithdraw_, address someAddress_) public {
        
        vm.assume(firstAmountToWithdraw_ < type(uint128).max);
        vm.assume(secondAmountToWithdraw_ < type(uint128).max);
        vm.assume(
            firstAmountToWithdraw_ + secondAmountToWithdraw_ < 32 ether 
            && 
            firstAmountToWithdraw_ > 0 ether 
            && 
            secondAmountToWithdraw_ > 0 ether
        );
       
        _fuzzTestRestrictions(someAddress_);

        address beneficiary = wrapper.owner();

        // Success case
        vm.deal(address(wrapper),32 ether);
        vm.startPrank(beneficiary);

        // Withdraw once

        bool returnStatus = wrapper.withdrawEther(firstAmountToWithdraw_, someAddress_);

        if(returnStatus != true){
            revert("The execution didn't return true!");
        }
        if(address(someAddress_).balance != firstAmountToWithdraw_){
            revert("It didn't withdraw the requested amount to the specified address");
        }
        if(address(wrapper).balance != 32 ether - firstAmountToWithdraw_){
            revert("It didn't withdraw the correct amount of ETH!");
        }
        returnStatus = false;

        // Withdraw a second time

        returnStatus = wrapper.withdrawEther(secondAmountToWithdraw_, someAddress_);

        if(returnStatus != true){
            revert("The execution didn't return true!");
        }
        if(address(someAddress_).balance != firstAmountToWithdraw_ + secondAmountToWithdraw_){
            revert("It didn't withdraw the requested amount to the specified address");
        }
        if(address(wrapper).balance != 32 ether - firstAmountToWithdraw_ - secondAmountToWithdraw_){
            revert("It didn't withdraw the correct amount of ETH!");
        }
        
    }


    // Test withdrawEther failure cases
    function testWithdrawEtherFailureCases(uint256 amountToWithdraw_, address someAddress_, address attacker_) public {
        
        vm.assume(attacker_ != wrapper.owner());
        vm.assume(amountToWithdraw_ < 32 ether && amountToWithdraw_ > 0 ether);
        _fuzzTestRestrictions(someAddress_);

        address beneficiary = wrapper.owner();

        // Failure cases

        // Cannot call if not owner
        vm.startPrank(attacker_);
        vm.expectRevert("Ownable: caller is not the owner");
        wrapper.withdrawEther(amountToWithdraw_, someAddress_);

        // Cannot withdraw zero amount
        vm.stopPrank();
        vm.startPrank(beneficiary);
        vm.expectRevert(WithdrawalRecipientRewardSplit.CannotWithdrawZeroAmount.selector);
        wrapper.withdrawEther(0, someAddress_);

        vm.deal(address(wrapper),10 ether);

        // Cannot withdraw more than the contract balance
        vm.stopPrank();
        vm.startPrank(beneficiary);
        vm.expectRevert(WithdrawalRecipientRewardSplit.InsufficientContractBalance.selector);
        wrapper.withdrawEther(10 ether + 1, someAddress_);

        vm.deal(address(wrapper), 33 ether);

        // Cannot withdraw more than 32 Ether
        vm.stopPrank();
        vm.startPrank(beneficiary);
        vm.expectRevert(WithdrawalRecipientRewardSplit.CannotWithdrawMoreThanPrincipal.selector);
        wrapper.withdrawEther(32 ether + 1, someAddress_);

        // After a partial withdrawal, cannot withdraw more than 32 ether cumulatively
        vm.stopPrank();
        vm.startPrank(beneficiary);
        wrapper.withdrawEther(amountToWithdraw_, someAddress_);
        vm.stopPrank();
        vm.startPrank(beneficiary);
        vm.expectRevert(WithdrawalRecipientRewardSplit.CannotWithdrawMoreThanPrincipal.selector);
        wrapper.withdrawEther(32 ether - amountToWithdraw_ + 1, someAddress_);

    }


    // Test withdrawAllEther success case by withdrawing once and then withdrawing all remaining
    // NOTE: This is a subcase of testWithdrawEther (where first + second == 32 ether)
    function testWithdrawAllEtherSuccessCases(uint256 firstAmountToWithdraw_, uint256 totalDeposits_, address someAddress_) public {
        
        vm.assume(firstAmountToWithdraw_ < type(uint128).max);
        vm.assume(totalDeposits_ < type(uint128).max);
        vm.assume(
            firstAmountToWithdraw_ < totalDeposits_
            && 
            firstAmountToWithdraw_ > 0 ether 
            && 
            totalDeposits_ + firstAmountToWithdraw_ <= 32 ether
        );
       
        _fuzzTestRestrictions(someAddress_);

        address beneficiary = wrapper.owner();

        // Success case
        vm.deal(address(0), 100 ether);
        vm.prank(address(0));
        payable(address(wrapper)).transfer(totalDeposits_);
        vm.startPrank(beneficiary);

        // Withdraw once

        bool returnStatus = wrapper.withdrawEther(firstAmountToWithdraw_, someAddress_);

        if(returnStatus != true){
            revert("The execution didn't return true!");
        }
        if(address(someAddress_).balance != firstAmountToWithdraw_){
            // console2.log(address(someAddress_).balance);
            revert(string.concat("It didn't withdraw the requested amount to the specified address. Balance: ",_toString(address(someAddress_).balance),". Expected Balance: ",_toString(firstAmountToWithdraw_)));
        }
        if(address(wrapper).balance != totalDeposits_ - firstAmountToWithdraw_){
            revert("It didn't withdraw the correct amount of ETH!");
        }
        returnStatus = false;

        // Withdraw a second time

        returnStatus = wrapper.withdrawAllEther(someAddress_);

        if(returnStatus != true){
            revert("The execution didn't return true!");
        }
        if(address(someAddress_).balance != totalDeposits_){
            revert("It didn't withdraw the remaining amount to the specified address");
        }
        if(address(wrapper).balance != 0){
            revert("It didn't withdraw all Ether from the wrapper");
        }
        
    }


    // Test withdrawAllEther failure cases 
    function testWithdrawAllEtherFailureCases(address someAddress_, address attacker_ ) public {
        
        vm.assume(attacker_ != wrapper.owner());
        _fuzzTestRestrictions(someAddress_);

        vm.deal(address(0), 100 ether);
        vm.prank(address(0));
        payable(address(wrapper)).transfer(32 ether);

        // Failure cases

        // Cannot call if not owner
        vm.startPrank(attacker_);
        vm.expectRevert("Ownable: caller is not the owner");
        wrapper.withdrawAllEther(someAddress_);

        // Other cases (zero withdrawal, cumulative > 32, etc.) are handled in withdrawEther (which this wraps)
        
        
    }


    // Test GetBeneficiaryPrincipalOwed success case by withdrawing once and then getting the balance owed
    function testGetBeneficiaryPrincipalOwed(uint256 firstAmountToWithdraw_, address someAddress_) public {
        
        vm.assume(firstAmountToWithdraw_ < type(uint128).max);
        vm.assume(
            firstAmountToWithdraw_ < 32 ether 
            && 
            firstAmountToWithdraw_ > 0 ether 
        );
       
        _fuzzTestRestrictions(someAddress_);

        address beneficiary = wrapper.owner();

        // Success case
        vm.deal(address(wrapper),32 ether);
        vm.startPrank(beneficiary);

        // Make sure initial value is 32 ETH
        uint256 remainingPrincipal = wrapper.getBeneficiaryPrincipalOwed();
        if(remainingPrincipal != 32 ether){
            revert("It didn't return the correct original value!");
        }

        // Withdraw once

        bool returnStatus = wrapper.withdrawEther(firstAmountToWithdraw_, someAddress_);

        if(returnStatus != true){
            revert("The execution didn't return true!");
        }
        if(address(someAddress_).balance != firstAmountToWithdraw_){
            console2.log(address(someAddress_).balance);
            revert("It didn't withdraw the requested amount to the specified address");
        }
        if(address(wrapper).balance != 32 ether - firstAmountToWithdraw_){
            revert("It didn't withdraw the correct amount of ETH!");
        }

        // Get the remaining principal owed

        remainingPrincipal = wrapper.getBeneficiaryPrincipalOwed();
       
        if(address(someAddress_).balance + remainingPrincipal != 32 ether){
            revert("Remaining principal and recipient balance don't add up to 32 ETH!");
        }
        if(address(wrapper).balance != remainingPrincipal){
            revert("It didn't withdraw the correct amount of ETH!");
        }
        
    }

    // SkimEther - Intended success case
    /** 

        @dev - This test is complicated! Let me explain how it works:
            1 - Set up a splitter and send it ETH
            2 - Call distributeETH to update splitter contract state (once per split, so one time in total)
            3 - Call withdraw to withdraw the ETH (once per address, so six times in total)
            4 - Make sure that the balances of the addresses changes by the correct amount!

        I have only fuzzed the amount here as 0xSplits is fussy when it comes to param ordering and fuzzing
        will just do virtually infinity global rejects for things like address arrays.

    */
    // Assumes beneficiary is active
    // Test skimEther success case by setting up a 0xSplits contract
    function testSkimEtherSuccessCaseBeneficiaryClaim(uint256 amount_)public{

        // STEP 0 - Assumptions

        vm.assume(amount_ > 1e6 && amount_ < 1000 ether);

        // STEP 1 - Create a deterministic splitter instance

        // Set up arrays of addresses and percentages
        address[] memory addresses = new address[](6);
        uint32[] memory percentages = new uint32[](6);
       
        addresses[0] = address(0x1111); // Validator 1
        percentages[0] = 1e6 * 0.0225;
        addresses[1] = address(0x2222); // Validator 2
        percentages[1] = 1e6 * 0.0225;
        addresses[2] = address(0x3333); // Validator 3
        percentages[2] = 1e6 * 0.0225;
        addresses[3] = address(0x4444); // Validator 4
        percentages[3] = 1e6 * 0.0225;

        addresses[4] = address(0x0b01000000000000000000000000000000000000); // Obol address
        percentages[4] = 1e6 * 0.0100;
        addresses[5] = address(0xbe4Ef1C1A4EE0000000000000000000000000000); // Beneficiary address (Must be ordered)
        percentages[5] = 1e6 * 0.9000;

        // Ensure that the sum of the percentages is 100%
        vm.assume(_getSum(percentages) == 1e6);

        // Create the deterministic splitter
        address splitterAddress = splitter.createSplit(
            addresses, /// @dev - Addresses must be in *ascending order* or SplitMain reverts
            percentages,
            0, // Distributor fee assumed to be zero
            address(0) // Using CREATE2 (deterministic splits) means that the controller must be the zero address
        );

        if(splitterAddress != wrapper.splitterAddress()){
            revert("The address of the created splitter contract is incorrect!");
        }

        // STEP 2 - Withdraw 32 ether for the beneficiary so we can skim

        address beneficiary = wrapper.owner();
        payable(address(wrapper)).transfer(32 ether);
        vm.prank(beneficiary);
        wrapper.withdrawAllEther(beneficiary);

        // STEP 3 - Send in some amount of Ether from staking
        
        vm.prank(address(0));
        vm.deal(address(0), amount_);
        console2.log("Sending the wrapper ",amount_);
        payable(address(wrapper)).transfer(amount_);

        
        // STEP 4 - Log address balances prior to withdrawing ETH 

        // The split is deterministic so we reuse addresses and therefore need to do this
        uint256 v1BalanceBefore = address(0x1111).balance;
        uint256 v2BalanceBefore = address(0x2222).balance;
        uint256 v3BalanceBefore = address(0x3333).balance;
        uint256 v4BalanceBefore = address(0x4444).balance;
        uint256 beneficiaryBalanceBefore = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance;
        uint256 obolBalanceBefore = address(0x0b01000000000000000000000000000000000000).balance;
        
        // STEP 5 - Call skimEther (updates the balances in the 0xSplits contract) for the split once
        
        bool returnStatus = wrapper.skimEther(addresses,percentages);
        if(returnStatus != true){
            revert("The execution didn't return true!");
        }

        // STEP 6 - Call withdraw (sends the money from 0xSplits to the address) for each of the addresses 

        // Create an empty ERC20[] array (SplitMain:withdraw uses as function param)
        ERC20[] memory emptyTokenArray = new ERC20[](0);

        // Withdraw from 0xSplits for each wallet
        vm.prank(address(0x1111));
        splitter.withdraw(address(0x1111),1,emptyTokenArray); 
        vm.prank(address(0x2222));
        splitter.withdraw(address(0x2222),1,emptyTokenArray); 
        vm.prank(address(0x3333));
        splitter.withdraw(address(0x3333),1,emptyTokenArray); 
        vm.prank(address(0x4444));
        splitter.withdraw(address(0x4444),1,emptyTokenArray); 
        vm.prank(address(0xbe4Ef1C1A4EE0000000000000000000000000000));
        splitter.withdraw(address(0xbe4Ef1C1A4EE0000000000000000000000000000),1,emptyTokenArray); 
        vm.prank(address(0x0b01000000000000000000000000000000000000));
        splitter.withdraw(address(0x0b01000000000000000000000000000000000000),1,emptyTokenArray); 

        // STEP 7 - Log the new balances of each address

        uint256 v1BalanceDiff = address(0x1111).balance - v1BalanceBefore;
        uint256 v2BalanceDiff = address(0x2222).balance - v2BalanceBefore;
        uint256 v3BalanceDiff = address(0x3333).balance - v3BalanceBefore;
        uint256 v4BalanceDiff = address(0x4444).balance - v4BalanceBefore;
        uint256 beneficiaryBalanceDiff = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance - beneficiaryBalanceBefore;
        uint256 obolBalanceDiff = address(0x0b01000000000000000000000000000000000000).balance - obolBalanceBefore;

        // STEP 8 - Check that the balances of the addresses are correct after they withdraw from 0xSplits
        
        /** 
            @dev This part needs explaining because it seems very "hacky" but it isn't in reality.
            So, firstly, SplitMain uses '_scaleAmountByPercentage' internally which I have copied here.
            However, all of the numbers are off by 1 Wei! Why is this? Well, we see 0xSplits say:
                "if mainBalance is positive, leave 1 in SplitMain for gas efficiency"
            So all of our calculations have to be off by 1 to pass the tests!
            In short: 0xSplits always shortchanges you 1 Wei.
        
        */

        // Four validators
        if(v1BalanceDiff != _scaleAmountByPercentage(amount_, percentages[0]) - 1){
            console2.log("The final balance of validator #1 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[0])-1," got ",v1BalanceDiff);
            revert("Validator #1 balance mismatch");
        }
        console2.log("1111:",_scaleAmountByPercentage(amount_, percentages[0]) - 1);
        if(v2BalanceDiff != _scaleAmountByPercentage(amount_, percentages[1]) - 1){
            console2.log("The final balance of validator #2 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[1])-1," got ",v2BalanceDiff);
            revert("Validator #2 balance mismatch");
        }
        console2.log("2222:",_scaleAmountByPercentage(amount_, percentages[1]) - 1);
        if(v3BalanceDiff != _scaleAmountByPercentage(amount_, percentages[2]) - 1){
            console2.log("The final balance of validator #3 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[2])-1," got ",v3BalanceDiff);
            revert("Validator #3 balance mismatch");
        }
        console2.log("3333:",_scaleAmountByPercentage(amount_, percentages[2]) - 1);
        if(v4BalanceDiff != _scaleAmountByPercentage(amount_, percentages[3]) - 1){
            console2.log("The final balance of validator #4 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[3])-1," got ",v4BalanceDiff);
            revert("Validator #4 balance mismatch");
        }
        console2.log("4444:",_scaleAmountByPercentage(amount_, percentages[3]) - 1);

        // Obol
        if(obolBalanceDiff != _scaleAmountByPercentage(amount_, percentages[4]) - 1){
            console2.log("The final balance Obol is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[4])-1," got ",obolBalanceDiff);
            revert("Obol balance mismatch");
        }
        console2.log("Obol:",_scaleAmountByPercentage(amount_, percentages[4]) - 1);

        // Beneficiary
        if(beneficiaryBalanceDiff != _scaleAmountByPercentage(amount_, percentages[5]) - 1){
            console2.log("The final balance of the beneficiary is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[5]) - 1," got ",beneficiaryBalanceDiff);
            revert("Beneficiary balance mismatch");
        }
        console2.log("Beneficiary:",_scaleAmountByPercentage(amount_, percentages[5]) - 1);

    } 

    // NEW SPEC - Beneficiary is always AWOL
    // Test skimEther success case by setting up a 0xSplits contract
    function testSkimEtherSuccessCaseValidatorClaim(uint256 amount_)public{

        // STEP 0 - Assumptions

        vm.assume(amount_ > 1e6 && amount_ < 1000 ether);

        // STEP 1 - Create a deterministic splitter instance

        // Set up arrays of addresses and percentages
        address[] memory addresses = new address[](6);
        uint32[] memory percentages = new uint32[](6);
       
        addresses[0] = address(0x1111); // Validator 1
        percentages[0] = 1e6 * 0.0225;
        addresses[1] = address(0x2222); // Validator 2
        percentages[1] = 1e6 * 0.0225;
        addresses[2] = address(0x3333); // Validator 3
        percentages[2] = 1e6 * 0.0225;
        addresses[3] = address(0x4444); // Validator 4
        percentages[3] = 1e6 * 0.0225;

        addresses[4] = address(0x0b01000000000000000000000000000000000000); // Obol address
        percentages[4] = 1e6 * 0.0100;
        addresses[5] = address(0xbe4Ef1C1A4EE0000000000000000000000000000); // Beneficiary address (Must be ordered)
        percentages[5] = 1e6 * 0.9000;

        // Ensure that the sum of the percentages is 100%
        vm.assume(_getSum(percentages) == 1e6);

        // Create the deterministic splitter
        address splitterAddress = splitter.createSplit(
            addresses, /// @dev - Addresses must be in *ascending order* or SplitMain reverts
            percentages,
            0, // Distributor fee assumed to be zero
            address(0) // Using CREATE2 (deterministic splits) means that the controller must be the zero address
        );

        if(splitterAddress != wrapper.splitterAddress()){
            revert("The address of the created splitter contract is incorrect!");
        }

        // STEP 2 - Deal the wrapper 33 ether - the first skim should give the beneficiary 32 and the second split 1

        payable(address(wrapper)).transfer(32 ether);

        // STEP 3 - Send in some amount of Ether from staking
        
        vm.prank(address(0));
        vm.deal(address(0), amount_);
        console2.log("Sending the wrapper ",amount_);
        payable(address(wrapper)).transfer(amount_);

        
        // STEP 4 - Log address balances prior to withdrawing ETH 

        // The split is deterministic so we reuse addresses and therefore need to do this
        uint256 v1BalanceBefore = address(0x1111).balance;
        uint256 v2BalanceBefore = address(0x2222).balance;
        uint256 v3BalanceBefore = address(0x3333).balance;
        uint256 v4BalanceBefore = address(0x4444).balance;
        uint256 beneficiaryBalanceBefore = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance;
        uint256 obolBalanceBefore = address(0x0b01000000000000000000000000000000000000).balance;
        
        // STEP 5 - Call skimEther (updates the balances in the 0xSplits contract) for the split once
        
        // Prank as a validator
        vm.prank(address(0x1111));
        // First skim will give the beneficiary 32 ether
        bool returnStatus = wrapper.skimEther(addresses,percentages);

        if(returnStatus != true){
            revert("The execution didn't return true!");
        }

        // Check that the beneficiary received 32 ETH
        uint256 beneficiaryBalanceIntermediate = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance;
        if(beneficiaryBalanceIntermediate - beneficiaryBalanceBefore != 32 ether){
            revert("The first skimEther did not give the lazy beneficiary their balance!");
        }
        // If the contract is not empty
        if(address(wrapper).balance != 0){
            revert("The contract didn't empty");
        }
        // Reset an earlier variable so the below tests work
        beneficiaryBalanceBefore = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance;


        // STEP 6 - Call withdraw (sends the money from 0xSplits to the address) for each of the addresses 

        // Create an empty ERC20[] array (SplitMain:withdraw uses as function param)
        ERC20[] memory emptyTokenArray = new ERC20[](0);

        // Withdraw from 0xSplits for each wallet
        vm.prank(address(0x1111));
        splitter.withdraw(address(0x1111),1,emptyTokenArray); 
        vm.prank(address(0x2222));
        splitter.withdraw(address(0x2222),1,emptyTokenArray); 
        vm.prank(address(0x3333));
        splitter.withdraw(address(0x3333),1,emptyTokenArray); 
        vm.prank(address(0x4444));
        splitter.withdraw(address(0x4444),1,emptyTokenArray); 
        vm.prank(address(0xbe4Ef1C1A4EE0000000000000000000000000000));
        splitter.withdraw(address(0xbe4Ef1C1A4EE0000000000000000000000000000),1,emptyTokenArray); 
        vm.prank(address(0x0b01000000000000000000000000000000000000));
        splitter.withdraw(address(0x0b01000000000000000000000000000000000000),1,emptyTokenArray); 

        // STEP 7 - Log the new balances of each address

        uint256 v1BalanceDiff = address(0x1111).balance - v1BalanceBefore;
        uint256 v2BalanceDiff = address(0x2222).balance - v2BalanceBefore;
        uint256 v3BalanceDiff = address(0x3333).balance - v3BalanceBefore;
        uint256 v4BalanceDiff = address(0x4444).balance - v4BalanceBefore;
        uint256 beneficiaryBalanceDiff = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance - beneficiaryBalanceBefore;
        uint256 obolBalanceDiff = address(0x0b01000000000000000000000000000000000000).balance - obolBalanceBefore;

        // STEP 8 - Check that the balances of the addresses are correct after they withdraw from 0xSplits
        
        /** 
            @dev This part needs explaining because it seems very "hacky" but it isn't in reality.
            So, firstly, SplitMain uses '_scaleAmountByPercentage' internally which I have copied here.
            However, all of the numbers are off by 1 Wei! Why is this? Well, we see 0xSplits say:
                "if mainBalance is positive, leave 1 in SplitMain for gas efficiency"
            So all of our calculations have to be off by 1 to pass the tests!
            In short: 0xSplits always shortchanges you 1 Wei.
        
        */

        // Four validators
        if(v1BalanceDiff != _scaleAmountByPercentage(amount_, percentages[0]) - 1){
            console2.log("The final balance of validator #1 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[0])-1," got ",v1BalanceDiff);
            revert("Validator #1 balance mismatch");
        }
        console2.log("1111:",_scaleAmountByPercentage(amount_, percentages[0]) - 1);
        if(v2BalanceDiff != _scaleAmountByPercentage(amount_, percentages[1]) - 1){
            console2.log("The final balance of validator #2 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[1])-1," got ",v2BalanceDiff);
            revert("Validator #2 balance mismatch");
        }
        console2.log("2222:",_scaleAmountByPercentage(amount_, percentages[1]) - 1);
        if(v3BalanceDiff != _scaleAmountByPercentage(amount_, percentages[2]) - 1){
            console2.log("The final balance of validator #3 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[2])-1," got ",v3BalanceDiff);
            revert("Validator #3 balance mismatch");
        }
        console2.log("3333:",_scaleAmountByPercentage(amount_, percentages[2]) - 1);
        if(v4BalanceDiff != _scaleAmountByPercentage(amount_, percentages[3]) - 1){
            console2.log("The final balance of validator #4 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[3])-1," got ",v4BalanceDiff);
            revert("Validator #4 balance mismatch");
        }
        console2.log("4444:",_scaleAmountByPercentage(amount_, percentages[3]) - 1);

        // Obol
        if(obolBalanceDiff != _scaleAmountByPercentage(amount_, percentages[4]) - 1){
            console2.log("The final balance Obol is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[4])-1," got ",obolBalanceDiff);
            revert("Obol balance mismatch");
        }
        console2.log("Obol:",_scaleAmountByPercentage(amount_, percentages[4]) - 1);

        // Beneficiary
        if(beneficiaryBalanceDiff != _scaleAmountByPercentage(amount_, percentages[5]) - 1){
            console2.log("The final balance of the beneficiary is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[5]) - 1," got ",beneficiaryBalanceDiff);
            revert("Beneficiary balance mismatch");
        }
        console2.log("Beneficiary:",_scaleAmountByPercentage(amount_, percentages[5]) - 1);

    } 


    // NEW SPEC - Beneficiary claims some amount and then goes AWOL
    // Test skimEther success case by setting up a 0xSplits contract
    function testSkimEtherSuccessCaseBeneficiaryAndValidatorClaim(uint256 amount_, uint256 beneficiaryTotalClaim_)public{

        // STEP 0 - Assumptions
        vm.assume(beneficiaryTotalClaim_ > 0 && beneficiaryTotalClaim_ < 32 ether);
        vm.assume(amount_ > 1e6 && amount_ < 1000 ether);

        // STEP 1 - Create a deterministic splitter instance

        // Set up arrays of addresses and percentages
        address[] memory addresses = new address[](6);
        uint32[] memory percentages = new uint32[](6);
       
        addresses[0] = address(0x1111); // Validator 1
        percentages[0] = 1e6 * 0.0225;
        addresses[1] = address(0x2222); // Validator 2
        percentages[1] = 1e6 * 0.0225;
        addresses[2] = address(0x3333); // Validator 3
        percentages[2] = 1e6 * 0.0225;
        addresses[3] = address(0x4444); // Validator 4
        percentages[3] = 1e6 * 0.0225;

        addresses[4] = address(0x0b01000000000000000000000000000000000000); // Obol address
        percentages[4] = 1e6 * 0.0100;
        addresses[5] = address(0xbe4Ef1C1A4EE0000000000000000000000000000); // Beneficiary address (Must be ordered)
        percentages[5] = 1e6 * 0.9000;

        // Ensure that the sum of the percentages is 100%
        vm.assume(_getSum(percentages) == 1e6);

        // Create the deterministic splitter
        address splitterAddress = splitter.createSplit(
            addresses, /// @dev - Addresses must be in *ascending order* or SplitMain reverts
            percentages,
            0, // Distributor fee assumed to be zero
            address(0) // Using CREATE2 (deterministic splits) means that the controller must be the zero address
        );

        if(splitterAddress != wrapper.splitterAddress()){
            revert("The address of the created splitter contract is incorrect!");
        }

        // STEP 2 - Deal the wrapper beneficiaryTotalClaim_ AND have them withdraw it - the first skim should give the beneficiary beneficiaryTotalClaim_

        address beneficiary = wrapper.owner();
        payable(address(wrapper)).transfer(beneficiaryTotalClaim_);
        vm.prank(beneficiary);
        wrapper.withdrawAllEther(beneficiary);


        // STEP 3 - Send in some amount of Ether from staking
        
        vm.prank(address(0));
        vm.deal(address(0), amount_);
        console2.log("Sending the wrapper ",amount_);
        payable(address(wrapper)).transfer(amount_);

        
        // STEP 4 - Log address balances prior to withdrawing ETH 

        // The split is deterministic so we reuse addresses and therefore need to do this
        uint256 v1BalanceBefore = address(0x1111).balance;
        uint256 v2BalanceBefore = address(0x2222).balance;
        uint256 v3BalanceBefore = address(0x3333).balance;
        uint256 v4BalanceBefore = address(0x4444).balance;
        uint256 beneficiaryBalanceBefore = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance;
        uint256 obolBalanceBefore = address(0x0b01000000000000000000000000000000000000).balance;
        
        // STEP 5 - Call skimEther (updates the balances in the 0xSplits contract) for the split once
        
        // Send the beneficiary the remaining amount they are owed 
        payable(address(wrapper)).transfer(32 ether - beneficiaryTotalClaim_);
        // Prank as a validator
        vm.prank(address(0x1111));
        // First skim will give the beneficiary the remaining amount
        bool returnStatus = wrapper.skimEther(addresses,percentages);

        if(returnStatus != true){
            revert("The execution didn't return true!");
        }

        // Check that the beneficiary received 32 ETH LESS beneficiaryTotalClaim_
        uint256 beneficiaryBalanceIntermediate = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance;
        if(beneficiaryBalanceIntermediate - beneficiaryBalanceBefore != 32 ether - beneficiaryTotalClaim_){
            revert("The first skimEther did not give the lazy beneficiary their balance!");
        }
        // If the contract is not empty
        if(address(wrapper).balance != 0){
            revert("The contract didn't empty");
        }
        // Reset an earlier variable so the below tests work
        beneficiaryBalanceBefore = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance;

        // STEP 6 - Call withdraw (sends the money from 0xSplits to the address) for each of the addresses 

        // Create an empty ERC20[] array (SplitMain:withdraw uses as function param)
        ERC20[] memory emptyTokenArray = new ERC20[](0);

        // Withdraw from 0xSplits for each wallet
        vm.prank(address(0x1111));
        splitter.withdraw(address(0x1111),1,emptyTokenArray); 
        vm.prank(address(0x2222));
        splitter.withdraw(address(0x2222),1,emptyTokenArray); 
        vm.prank(address(0x3333));
        splitter.withdraw(address(0x3333),1,emptyTokenArray); 
        vm.prank(address(0x4444));
        splitter.withdraw(address(0x4444),1,emptyTokenArray); 
        vm.prank(address(0xbe4Ef1C1A4EE0000000000000000000000000000));
        splitter.withdraw(address(0xbe4Ef1C1A4EE0000000000000000000000000000),1,emptyTokenArray); 
        vm.prank(address(0x0b01000000000000000000000000000000000000));
        splitter.withdraw(address(0x0b01000000000000000000000000000000000000),1,emptyTokenArray); 

        // STEP 7 - Log the new balances of each address

        uint256 v1BalanceDiff = address(0x1111).balance - v1BalanceBefore;
        uint256 v2BalanceDiff = address(0x2222).balance - v2BalanceBefore;
        uint256 v3BalanceDiff = address(0x3333).balance - v3BalanceBefore;
        uint256 v4BalanceDiff = address(0x4444).balance - v4BalanceBefore;
        uint256 beneficiaryBalanceDiff = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance - beneficiaryBalanceBefore;
        uint256 obolBalanceDiff = address(0x0b01000000000000000000000000000000000000).balance - obolBalanceBefore;

        // STEP 8 - Check that the balances of the addresses are correct after they withdraw from 0xSplits
        
        /** 
            @dev This part needs explaining because it seems very "hacky" but it isn't in reality.
            So, firstly, SplitMain uses '_scaleAmountByPercentage' internally which I have copied here.
            However, all of the numbers are off by 1 Wei! Why is this? Well, we see 0xSplits say:
                "if mainBalance is positive, leave 1 in SplitMain for gas efficiency"
            So all of our calculations have to be off by 1 to pass the tests!
            In short: 0xSplits always shortchanges you 1 Wei.
        
        */

        // Four validators
        if(v1BalanceDiff != _scaleAmountByPercentage(amount_, percentages[0]) - 1){
            console2.log("The final balance of validator #1 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[0])-1," got ",v1BalanceDiff);
            revert("Validator #1 balance mismatch");
        }
        console2.log("1111:",_scaleAmountByPercentage(amount_, percentages[0]) - 1);
        if(v2BalanceDiff != _scaleAmountByPercentage(amount_, percentages[1]) - 1){
            console2.log("The final balance of validator #2 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[1])-1," got ",v2BalanceDiff);
            revert("Validator #2 balance mismatch");
        }
        console2.log("2222:",_scaleAmountByPercentage(amount_, percentages[1]) - 1);
        if(v3BalanceDiff != _scaleAmountByPercentage(amount_, percentages[2]) - 1){
            console2.log("The final balance of validator #3 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[2])-1," got ",v3BalanceDiff);
            revert("Validator #3 balance mismatch");
        }
        console2.log("3333:",_scaleAmountByPercentage(amount_, percentages[2]) - 1);
        if(v4BalanceDiff != _scaleAmountByPercentage(amount_, percentages[3]) - 1){
            console2.log("The final balance of validator #4 is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[3])-1," got ",v4BalanceDiff);
            revert("Validator #4 balance mismatch");
        }
        console2.log("4444:",_scaleAmountByPercentage(amount_, percentages[3]) - 1);

        // Obol
        if(obolBalanceDiff != _scaleAmountByPercentage(amount_, percentages[4]) - 1){
            console2.log("The final balance Obol is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[4])-1," got ",obolBalanceDiff);
            revert("Obol balance mismatch");
        }
        console2.log("Obol:",_scaleAmountByPercentage(amount_, percentages[4]) - 1);

        // Beneficiary
        if(beneficiaryBalanceDiff != _scaleAmountByPercentage(amount_, percentages[5]) - 1){
            console2.log("The final balance of the beneficiary is incorrect: expected",_scaleAmountByPercentage(amount_, percentages[5]) - 1," got ",beneficiaryBalanceDiff);
            revert("Beneficiary balance mismatch");
        }
        console2.log("Beneficiary:",_scaleAmountByPercentage(amount_, percentages[5]) - 1);

    } 

    // Test skimEther failure case by setting up a 0xSplits contract
    function testSkimEtherFailureCases(uint256 amountInContract_)public{

        // Code is from testSkimEtherSuccessCase but we don't send in 32E to skim
        vm.assume(amountInContract_ > 1e6 && amountInContract_ < 32 ether);

        address[] memory addresses = new address[](6);
        uint32[] memory percentages = new uint32[](6);
        addresses[0] = address(0x1111); // Validator 1
        percentages[0] = 1e6 * 0.0225;
        addresses[1] = address(0x2222); // Validator 2
        percentages[1] = 1e6 * 0.0225;
        addresses[2] = address(0x3333); // Validator 3
        percentages[2] = 1e6 * 0.0225;
        addresses[3] = address(0x4444); // Validator 4
        percentages[3] = 1e6 * 0.0225;

        addresses[4] = address(0x0b01000000000000000000000000000000000000); // Obol address
        percentages[4] = 1e6 * 0.0100;
        addresses[5] = address(0xbe4Ef1C1A4EE0000000000000000000000000000); // Beneficiary address (Must be ordered)
        percentages[5] = 1e6 * 0.9000;

        // Ensure that the sum of the percentages is 100%
        vm.assume(_getSum(percentages) == 1e6);

        // Create the deterministic splitter
        address splitterAddress = splitter.createSplit(
            addresses, /// @dev - Addresses must be in *ascending order* or SplitMain reverts
            percentages,
            0, // Distributor fee assumed to be zero
            address(0) // Using CREATE2 (deterministic splits) means that the controller must be the zero address
        );

        if(splitterAddress != wrapper.splitterAddress()){
            revert("The address of the created splitter contract is incorrect!");
        }

        // STEP 2 - Send in an amount less than 32 ether - so skim should always fail now

        address beneficiary = wrapper.owner();
        vm.deal(address(wrapper),amountInContract_);
        vm.prank(beneficiary);
        wrapper.withdrawAllEther(beneficiary);

        // Try and skim - it should fail
        vm.expectRevert(WithdrawalRecipientRewardSplit.BeneficiaryPrincipalNotRepaidYet.selector);
        wrapper.skimEther(addresses,percentages);
        
    } 

    // Narrative test - simulating what a typical lifecycle for the wrapper contract will look like
    /** @dev
        Cashflows are:
        0.6 IN
        31.9 IN (0.1 SLASHED)
        0.2 IN
        Results are:
        Beneficiary 32 ETH
        Others share 0.7 ETH
    */
    //
    //
    function testNarrative() public {

        // Set up a splitter to wrap (code from testSkimEther)
        address[] memory addresses = new address[](6);
        uint32[] memory percentages = new uint32[](6);
        addresses[0] = address(0x1111); // Validator 1
        percentages[0] = 1e6 * 0.0225;
        addresses[1] = address(0x2222); // Validator 2
        percentages[1] = 1e6 * 0.0225;
        addresses[2] = address(0x3333); // Validator 3
        percentages[2] = 1e6 * 0.0225;
        addresses[3] = address(0x4444); // Validator 4
        percentages[3] = 1e6 * 0.0225;
        addresses[4] = address(0x0b01000000000000000000000000000000000000); // Obol address
        percentages[4] = 1e6 * 0.0100;
        addresses[5] = address(0xbe4Ef1C1A4EE0000000000000000000000000000); // Beneficiary address (Must be ordered)
        percentages[5] = 1e6 * 0.9000;
        vm.assume(_getSum(percentages) == 1e6);
        splitter.createSplit(
            addresses, 
            percentages,
            0, 
            address(0) 
        );
        
        // The wrapper will receive money from ETH staking over time
        vm.deal(address(0), 100 ether);
        vm.prank(address(0));

        // Send the wrapper one year of staking rewards
        for (uint256 i = 0; i < 12; i++){
            payable(address(wrapper)).transfer(0.05 ether);
        }

        // A validator tries to skim the ether - they can't
        vm.prank(address(0x1111));
        vm.expectRevert(WithdrawalRecipientRewardSplit.BeneficiaryPrincipalNotRepaidYet.selector);
        wrapper.skimEther(addresses, percentages);

        // The beneficiary decides to withdraw 1 year of staking rewards
        uint256 beneficiaryBalanceBefore = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance;
        vm.prank(address(0xbe4Ef1C1A4EE0000000000000000000000000000));
        wrapper.withdrawAllEther(beneficiaryAddress);
        uint256 beneficiaryBalanceAfter = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance;
        if(beneficiaryBalanceAfter - beneficiaryBalanceBefore != 0.6 ether){
            revert("The beneficiary didn't get all the staking rewards!");
        }
        if(address(wrapper).balance != 0 ether){
            revert("The contract's balance is incorrect!");
        }

        // Another few months pass, 3 more months of staking rewards come in
        // Send the wrapper one year of staking rewards
        for (uint256 i = 0; i < 4; i++){
            payable(address(wrapper)).transfer(0.05 ether);
        }

        // The beneficiary decides to close down the validator
        // 31.90 ether is sent into the contract as they have been slashed
        payable(address(wrapper)).transfer(31.90 ether);

        // The validators use skimEther and sends 31.4 out to the beneficiary, leaving 0.7 in the contract
        vm.prank(address(0x1111));
        wrapper.skimEther(addresses,percentages);
        if(address(wrapper).balance != 0 ether){ /// @dev Was 0.7 in multi skimEther call implementation
            revert("The contract's balance is incorrect!");
        }

        beneficiaryBalanceAfter = address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance;
        if(beneficiaryBalanceAfter - beneficiaryBalanceBefore != 32 ether){
            revert("The beneficiary didn't get all their capital back!");
        }
        if(address(wrapper).balance != 0 ether){
            revert("The contract's balance is incorrect!");
        }
        

        // Addresses call the splitter to retrieve funds from 0xSplits
        ERC20[] memory emptyTokenArray = new ERC20[](0);
        vm.prank(address(0x1111));
        splitter.withdraw(address(0x1111),1,emptyTokenArray); 
        vm.prank(address(0xbe4Ef1C1A4EE0000000000000000000000000000));
        splitter.withdraw(address(0xbe4Ef1C1A4EE0000000000000000000000000000),1,emptyTokenArray); 
        vm.prank(address(0x0b01000000000000000000000000000000000000));
        splitter.withdraw(address(0x0b01000000000000000000000000000000000000),1,emptyTokenArray); 

        // Final checks to make sure the numbers add up
        // Principal is 32 ETH + 0.7 ETH total rewards (0.1 ETH lost due to slashing)
        if(address(0x1111).balance != _scaleAmountByPercentage(0.7 ether, percentages[0]) - 1 ){
            revert("The validator's final balance is incorrect!");
        }
        if(address(0x0b01000000000000000000000000000000000000).balance 
            != _scaleAmountByPercentage(0.7 ether, percentages[4]) - 1 
        ){
            revert("Obol's final balance is incorrect!");
        }
        if(address(0xbe4Ef1C1A4EE0000000000000000000000000000).balance 
            != 
            (32 ether + _scaleAmountByPercentage(0.7 ether, percentages[5]) - 1 )
        ){
            revert("The beneficiary's final balance is incorrect!");
        }


    }


}
