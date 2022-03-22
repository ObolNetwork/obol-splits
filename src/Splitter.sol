// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "splits-contracts/interfaces/ISplitMain.sol";

/// @notice A deployer contract which deploys fixed-cut 0xSplitter contracts.
/// @author Obol Labs Inc. (https://github.com/ObolNetwork)
contract ObolSplitterDeployer { 
    /*///////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    ISplitMain public immutable splitterContract;
    address public immutable obolWallet;

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(ISplitMain _splitterContract, address _obolWallet) {
        splitterContract = _splitterContract;
        obolWallet = _obolWallet;
    }


    function deploy(address[] calldata accounts) public returns (address) {
        // Calculate percentAllocations.
        uint32[] memory percentAllocations = new uint32[](accounts.length + 1);
        // 4% standard share for Obol
        uint32 obolShare = 40000;
        uint32 validatorShare = 960000;
        uint32 sharePerValidator = validatorShare / uint32(accounts.length);
        uint32 totalValidatorShare = sharePerValidator * uint32(accounts.length);

        // Return the difference to Obol, if any.
        if (totalValidatorShare < validatorShare) {
            obolShare += validatorShare - totalValidatorShare;
        }

        for (uint256 i = 0; i < accounts.length; i++) {
            percentAllocations[i] = sharePerValidator;
        }

        percentAllocations[accounts.length] = obolShare;

        // Inject obol address to accounts.
        address[] memory fullAccountList = new address[](accounts.length + 1);

        for (uint256 i = 0; i < accounts.length; i++) {
            fullAccountList[i] = accounts[i];
        }

        fullAccountList[accounts.length] = obolWallet;
        return splitterContract.createSplit(fullAccountList, percentAllocations, 0, msg.sender);
    }
}

