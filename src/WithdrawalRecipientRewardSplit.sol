// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {SplitMain} from 'src/SplitMain.sol';
import "openzeppelin-contracts/contracts/access/Ownable.sol";


/// @title A wrapper for 0xSplits deterministic splitter instances
/// @author 0xArbiter on behalf of Obol Labs
/// @notice This contract will wrap a 0xSplits deterministic splitter and do some checks. It will also hold ETH.
/// @notice This contract constains withdraw functions for the beneficiary and a skim function for validators / Obol
/// @dev The receive function does not emit an event but I have left the event code in here (commented out)
contract WithdrawalRecipientRewardSplit is Ownable {

    // If the beneficiary tries to withdraw zero Ether
    error CannotWithdrawZeroAmount();
    // If a user tries to withdraw Ether but they are not the beneficiary
    error SenderIsNotBeneficiary();
    // If the beneficiary tries to withdraw more than the 32 ETH principal
    error CannotWithdrawMoreThanPrincipal();
    // If the contract doesn't have enough Ether to skim from
    error InsufficientContractBalance();
    // If the beneficiary has not withdrawn 32 ether yet
    error BeneficiaryPrincipalNotRepaidYet();
    
    /// @dev [Optional] Event for receive function
    // event WrapperReceivedETH(address, uint);
    receive() payable external{}
    
    // Define a SplitMain object, we will pass in the address of the contract in the constructor
    SplitMain splitter;

    // Constructor takes the deterministic splitter address and the 0xSplits SplitMain contract address
    constructor (address splitterAddress_, SplitMain _splitmain) {
        splitter = _splitmain;
        splitterAddress = splitterAddress_;
    }

    // Address of the deterministic splitter contract
    address public splitterAddress ;

    // Measures how much ETH the beneficiary has withdrawn so far
    // When this reaches 32, we can skim ETH
    uint256 cumulativeWithdrawn; 


    /// @notice Determines how much ETH the beneficiary can withdraw (cumulatively 32)
    /// @dev Can be called by frontend or similar as a QoL improvement
    function getBeneficiaryPrincipalOwed() view public returns(uint256) {

        return (32 ether - cumulativeWithdrawn);

    }

    
    /// @notice Allows withdrawal an amount of Ether from this contract to a specified address by the beneficiary
    /// @param amount_ the amount of ETH to withdraw
    /// @param recipientAddress_ the address to which ETH is being withdrawn
    /// @return status is true on successful execution
    function withdrawEther(uint256 amount_, address recipientAddress_) public onlyOwner returns(bool status) {
        
        // Withdrawing party must be this contract's owner (the beneficiary)
        // Check that the withdrawal amount isn't zero
        if(amount_ == 0){
            revert CannotWithdrawZeroAmount();
        }
        // Check that the withdrawal isn't more than the contract balance
        if(amount_ > address(this).balance){
            revert InsufficientContractBalance();
        }
        // Check that the beneficiary is not withdrawing more than the total 32 ETH principal
        if(amount_ + cumulativeWithdrawn > 32 ether){
            revert CannotWithdrawMoreThanPrincipal();
        }
        // Update beneficiary cumulative withdrawal amount
        cumulativeWithdrawn += amount_;
        // Withdraw the amount of Ether
        payable(recipientAddress_).transfer(amount_);
        // Set return status to true
        status = true;

    }


    /// @notice Withdraws all remaining Ether owed to the beneficiary to a specified address
    /// @dev Just a wrapper around withdrawEther (QoL extension for end users)
    /// @param recipientAddress_ the address to which ETH is being withdrawn
    /// @return status is true on successful execution
    function withdrawAllEther(address recipientAddress_) external onlyOwner returns(bool status){

        // Call the withdrawEther function with the contract balance as the amount parameter
        if(address(this).balance <= 32 ether){
            // Withdraw entire contract balance
            status = withdrawEther(address(this).balance, recipientAddress_); 
        }else{
            // Withdraw maximum 32 ether
            status = withdrawEther(32 ether, recipientAddress_); 
        }

    }
    

    /// @notice Sends the entire balance of this contract to the deterministic splitter
    /// @dev Since this wraps 0xSplits and 0xSplits stores hashes, we need to pass in params every time
    /// @dev The addresses array must be in *ascending order* for 0xSplits to not revert
    /// @dev This is currently marked as external - add onlyOperator or some access control in prod
    /// @param addresses_ the addresses for the deterministic splitter sorted in *ascending order*
    /// @param percentages_ the assigned split percentages for the deterministic splitter
    /// @return status is true on successful execution
    function skimEther(address[] calldata addresses_, uint32[] calldata percentages_) external returns (bool status){ 
        
        /// @dev You must add your custom onlyOperator code here or use a modifier in prod
        
        // Check that we are leaving 32ETH for the beneficiary in here, or this won't run
        if(address(this).balance + cumulativeWithdrawn <= 32 ether){
            revert BeneficiaryPrincipalNotRepaidYet();
        }
        // Calculate how much we are sending the splitter 
        uint256 amountToSend = address(this).balance - (32 ether - cumulativeWithdrawn);
        // Transfer the ETH to the deterministic splitter (these are two commands for readability)
        payable(splitterAddress).transfer(amountToSend);
        // Call distributeETH on SplitMain's address
        splitter.distributeETH(
            splitterAddress, // The address of the deterministic splitter
            addresses_,
            percentages_,
            0, // Distributor fee is 0
            address(0) // Controller is 0 for deterministic splitters
        );
        // Set return status to true
        status = true;

    }

}
