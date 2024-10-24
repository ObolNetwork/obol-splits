// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import {SymPod, ISymPod} from "src/symbiotic/SymPod.sol";
import "forge-std/Test.sol";

contract SymPodHarness is SymPod, Test {
    constructor(
        address _symPodConfigurator,
        address _eth2DepositContract,
        address _beaconRootsOracle,
        uint256 _withdrawDelayPeriod,
        uint256 _balanceDelta
    ) SymPod(
        _symPodConfigurator,
        _eth2DepositContract,
        _beaconRootsOracle,
        _withdrawDelayPeriod,
        _balanceDelta
    ) {
    }

    function changeValidatorStateToActive(bytes32 pubKeyHash) external {
        validatorInfo[pubKeyHash].status = ISymPod.VALIDATOR_STATE.ACTIVE;
    }

    function changeValidatorStateToInActive(bytes32 pubKeyHash) external {
        validatorInfo[pubKeyHash].status = ISymPod.VALIDATOR_STATE.INACTIVE;
    }

    function setValidatorIndex(bytes32 pubKeyHash, uint40 validatorIndex) external {
        validatorInfo[pubKeyHash].validatorIndex = validatorIndex;
    }
    
    function setValidatorRestakedGwei(bytes32 pubKeyHash, uint64 restakedGwei) external {
        validatorInfo[pubKeyHash].restakedBalanceGwei = restakedGwei;
    }

    function changeValidatorLastCheckpointedAt(bytes32 pubKeyHash, uint64 val) external {
        validatorInfo[pubKeyHash].lastCheckpointedAt = val;
    }

    function setNumberOfValidators(uint256 num) external {
        numberOfActiveValidators = uint64(num);
    }

    function setWithdrawableRestakedPodWei(uint256 num) external {
        withdrawableRestakedPodWei = num;
    }

    function setCurrentCheckpointTimestamp(uint64 timestamp) external {
        currentCheckPointTimestamp = timestamp;
    }

    function mintSharesPlusAssetsAndRestakedPodWei (uint256 amount, address holder) external {
        _mint(holder, amount);
        totalRestakedETH += amount;
        withdrawableRestakedPodWei += amount;
    }

    function setTotalRestakedETH(uint256 num) external {
        totalRestakedETH = num;
    }

    function _verifyValidatorWithdrawalCredentials(bytes32[] calldata validatorFields) internal pure override {
        validatorFields = validatorFields;
    }
}
