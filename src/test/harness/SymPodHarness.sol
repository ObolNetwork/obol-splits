// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import {SymPod, ISymPod} from "src/symbiotic/SymPod.sol";
import "forge-std/Test.sol";

contract SymPodHarness is SymPod, Test {
    constructor(
        address _symPodConfigurator,
        address _eth2DepositContract,
        address _beaconRootsOracle,
        uint256 _withdrawDelayPeriod
    ) SymPod(
        _symPodConfigurator,
        _eth2DepositContract,
        _beaconRootsOracle,
        _withdrawDelayPeriod
    ) {
    }

    function changeValidatorStateToActive(bytes32 pubKeyHash) external {
        console.log(uint256(validatorInfo[pubKeyHash].status));
        console.log(uint256(validatorInfo[pubKeyHash].restakedBalanceGwei));
        validatorInfo[pubKeyHash].status = ISymPod.VALIDATOR_STATUS.WITHDRAWN;
        console.log(uint256(validatorInfo[pubKeyHash].status));
    }

    function setNumberOfValidators(uint256 num) external {
        numberOfActiveValidators = uint64(num);
    }

    function setWithdrawableExecutionLayerGwei(uint256 num) external {
        withdrawableRestakedExecutionLayerGwei = uint64(num);
    }

    function mintSharesPlusAssetsAndExecutionLayerGwei(uint256 amount, address holder) external {
        _mint(holder, amount);
        totalRestakedETH += amount;
        withdrawableRestakedExecutionLayerGwei += uint64(amount);
    }



    function setTotalRestakedETH(uint256 num) external {
        totalRestakedETH = num;
    }

    function _verifyValidatorWithdrawalCredentials(bytes32[] calldata validatorFields) internal pure override {
        validatorFields = validatorFields;
    }
}
