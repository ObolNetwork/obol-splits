// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;     

import {Clone} from "solady/utils/Clone.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ObolRocketPoolStorage} from "./ObolRocketPoolStorage.sol";
import {IRocketDepositPool} from "../interfaces/external/rocketPool/IRocketDepositPool.sol";
import {IRocketPoolStorage} from "../interfaces/external/rocketPool/IRocketPoolStorage.sol";
import {IRocketPoolMinipoolManager} from "../interfaces/external/rocketPool/IRocketPoolMinipoolManager.sol";
import {IRocketMinipool} from "../interfaces/external/rocketPool/IRocketMinipool.sol";
import {IRETH} from "../interfaces/external/rocketPool/IRETH.sol";


contract ObolRocketPoolRecipient is Clone {
    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------
    /// Invalid minipool deposit amount
    error InvalidDepositAmount();

    /// Invalid token recovery
    error InvalidTokenRecovery();

    /// Invalid token recovery recipient
    error InvalidTokenRecovery_InvalidRecipient();

    /// Invalid minipool
    error InvalidMinipool_Address();

    /// Minipool does not allow distribution
    error InvalidMinipool_Distribute();

    /// Invalid distribution
    error InvalidDistribution_TooLarge();

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------
    /// Emitted after non-ETH tokens are recovered to a recipient
    /// @param recoveryAddressToken Recovered token
    /// @param recipient Address receiving recovered token
    /// @param amount Amount of recovered token
    event RecoverFunds(address recoveryAddressToken, address recipient, uint256 amount);

    /// Emitted after funds are distributed to recipients
    /// @param principalPayout Amount of principal paid out
    /// @param rewardPayout Amount of reward paid out
    /// @param pullFlowFlag Flag for pushing funds to recipients or storing for
    /// pulling
    event DistributeFunds(uint256 principalPayout, uint256 rewardPayout, uint256 pullFlowFlag);


    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// storage - constants
    /// -----------------------------------------------------------------------

    uint256 internal constant FEE_AMOUNT = 2875; // 2.875%
    uint256 internal constant FEE_PRECISION = 100_000;
    address internal constant ETH_ADDRESS = address(0);
    uint256 internal constant MINIPOOL_AMOUNT = 8 ether;

    uint256 internal constant PUSH = 0;
    uint256 internal constant PULL = 1;

    uint256 internal constant ONE_WORD = 32;
    uint256 internal constant ADDRESS_BITS = 160;

    /// @dev threshold for pushing balance update as reward or principal
    uint256 internal constant BALANCE_CLASSIFICATION_THRESHOLD = 4 ether;
    uint256 internal constant PRINCIPAL_RECIPIENT_INDEX = 0;
    uint256 internal constant REWARD_RECIPIENT_INDEX = 1;

    /// -----------------------------------------------------------------------
    /// storage - cwia offsets
    /// -----------------------------------------------------------------------

    uint256 internal constant STORAGE_ADDRESS_OFFSET = 0;

    // token (address, 20 bytes), recoveryAddress (address, 20 bytes),
    // tranches (uint256[], numTranches * 32 bytes)

    uint256 internal constant RECOVERY_ADDRESS_OFFSET = 20;
    // 20 = recoveryAddress_offset (0) + recoveryAddress_size (address, 20
    // bytes)
    uint256 internal constant TRANCHES_OFFSET = 40;

    function rpStorage() public pure returns (address) {
        return _getArgAddress(STORAGE_ADDRESS_OFFSET);
    }

    /// Address to recover non-OWR tokens to
    /// @dev equivalent to address public immutable recoveryAddress;
    function recoveryAddress() public pure returns (address) {
        return _getArgAddress(RECOVERY_ADDRESS_OFFSET);
    }

    /// Get OWR tranche `i`
    /// @dev emulates to uint256[] internal immutable tranche;
    function _getTranche(uint256 i) internal pure returns (uint256) {
        unchecked {
        // shouldn't overflow
            return _getArgUint256(TRANCHES_OFFSET + i * ONE_WORD);
        }
    }

    /// -----------------------------------------------------------------------
    /// storage - mutables
    /// -----------------------------------------------------------------------

    /// Amount of active balance set aside for pulls
    /// @dev ERC20s with very large decimals may overflow & cause issues
    uint128 public fundsPendingWithdrawal;

    /// Amount of distributed OWRecipient token for principal
    /// @dev Would be less than or equal to amount of stake
    /// @dev ERC20s with very large decimals may overflow & cause issues
    uint128 public claimedPrincipalFunds;

    /// Mapping to account balances for pulling
    mapping(address => uint256) internal pullBalances;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    // solhint-disable-next-line no-empty-blocks
    /// clone implementation doesn't use constructor
    constructor() {}

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

     /// -----------------------------------------------------------------------
    /// functions - view & pure
    /// -----------------------------------------------------------------------

    /// Return unpacked tranches
    /// @return principalRecipient Addres of principal recipient
    /// @return rewardRecipient Address of reward recipient
    /// @return amountOfPrincipalStake Absolute payment threshold for principal
    function getTranches()
        public
        pure
        returns (address principalRecipient, address rewardRecipient, uint256 amountOfPrincipalStake)
    {
        uint256 tranche = _getTranche(PRINCIPAL_RECIPIENT_INDEX);
        principalRecipient = address(uint160(tranche));
        amountOfPrincipalStake = tranche >> ADDRESS_BITS;

        rewardRecipient = address(uint160(_getTranche(REWARD_RECIPIENT_INDEX)));
    }

    function viewRewards(address _miniPool) public view returns (uint256) {
        ObolRocketPoolStorage _rpStorage = ObolRocketPoolStorage(rpStorage());
        address miniPoolManager = _rpStorage.rocketPoolMinipoolManager();
        if(!IRocketPoolMinipoolManager(miniPoolManager).getMinipoolExists(_miniPool)) revert InvalidMinipool_Address();
        
        uint256 nodeRefundBalance = IRocketMinipool(_miniPool).getNodeRefundBalance();
        uint256 balance = _miniPool.balance;
        return balance - nodeRefundBalance;
    }


    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------
    /// Recover tokens to a recipient
    /// @param _recoverToken Token to recover
    /// @param recipient Address to receive recovered token
    function recoverFunds(address _recoverToken, address recipient) external payable {
        /// checks

        // revert if caller tries to recover OWRecipient token
        if (_recoverToken == ETH_ADDRESS) revert InvalidTokenRecovery();

        // if recoveryAddress is set, recipient must match it
        // else, recipient must be one of the OWR recipients
        address _recoveryAddress = recoveryAddress();
        if (_recoveryAddress == address(0)) {
            // ensure txn recipient is a valid OWR recipient
            (address principalRecipient, address rewardRecipient,) = getTranches();
            if (recipient != principalRecipient && recipient != rewardRecipient) {
                revert InvalidTokenRecovery_InvalidRecipient();
            }
        } else if (recipient != _recoveryAddress) {
            revert InvalidTokenRecovery_InvalidRecipient();
        }

        /// effects

        /// interactions

        // recover non-target token
        uint256 amount = ERC20(_recoverToken).balanceOf(address(this));
        _recoverToken.safeTransfer(recipient, amount);

        emit RecoverFunds(_recoverToken, recipient, amount);
    }
    

    // TODO: chat if we should create the minipool or search for vacant minipools
    //       also, should the contract handle `preDeposit`
    // ? How do we get the minipool address?
    // ? where is RPL added?
    function depositFunds() external payable {
        if (msg.value < MINIPOOL_AMOUNT) revert InvalidDepositAmount();

        ObolRocketPoolStorage _rpStorage = ObolRocketPoolStorage(rpStorage());
        address depositAddress = _rpStorage.rocketPoolDeposit();
        IRocketDepositPool(depositAddress).deposit{value: msg.value}();
    }


    function distributeFunds(address _miniPool, bool _rewards, uint256 pullFlowFlag) external {
        ObolRocketPoolStorage _rpStorage = ObolRocketPoolStorage(rpStorage());
        {
            address miniPoolManager = _rpStorage.rocketPoolMinipoolManager();
            if(!IRocketPoolMinipoolManager(miniPoolManager).getMinipoolExists(_miniPool)) revert InvalidMinipool_Address();
        }

        IRocketMinipool pool = IRocketMinipool(_miniPool);
        if (!pool.userDistributeAllowed()) revert InvalidMinipool_Distribute();

        address rEth = _rpStorage.rEth();
        uint256 rEthBalanceBefore = rEth.balance;
        pool.distributeBalance(_rewards);
        uint256 available  = rEth.balance - rEthBalanceBefore;
        
        address rETH = _rpStorage.rEth();
        IRETH(rETH).burn(available);

        // TODO: what address should we use for the fee cut?
        address _recoveryAddress = recoveryAddress();
        if (_recoveryAddress == address(0)) revert InvalidTokenRecovery_InvalidRecipient();

        uint256 feeAmount = available * FEE_AMOUNT / FEE_PRECISION;
        available -= feeAmount;
        
        // payout fees
        _payout(_recoveryAddress, feeAmount, pullFlowFlag);

        _distribute(available, pullFlowFlag);
    }
    
    /// -----------------------------------------------------------------------
    /// functions - private & internal
    /// -----------------------------------------------------------------------
    function _payout(address recipient, uint256 payoutAmount, uint256 pullFlowFlag) internal {
        if (payoutAmount > 0) {
            if (pullFlowFlag == PULL) {
                // Write to Storage
                pullBalances[recipient] += payoutAmount;
            } else {
                recipient.safeTransferETH(payoutAmount);
            }
        }
    }

    function _getMinipoolQueue() private view returns (address) {
        ObolRocketPoolStorage _rpStorage = ObolRocketPoolStorage(rpStorage());
        address storageAddress = _rpStorage.rocketPoolStorage();
        address miniPoolQueue = IRocketPoolStorage(storageAddress).getAddress(keccak256(abi.encodePacked("contract.address", "rocketMinipoolQueue")));
        return miniPoolQueue;
    }
    

    function _distribute(uint256 available, uint256 pullFlowFlag) private {
        uint256 _claimedPrincipalFunds = uint256(claimedPrincipalFunds);
        uint256 _memoryFundsPendingWithdrawal = uint256(fundsPendingWithdrawal);

        uint256 _fundsToBeDistributed = available - _memoryFundsPendingWithdrawal;
        (address principalRecipient, address rewardRecipient, uint256 amountOfPrincipalStake) = getTranches();

        uint256 _principalPayout = 0;
        uint256 _rewardPayout = 0;

        unchecked {
            // _claimedPrincipalFunds should always be <= amountOfPrincipalStake
            uint256 principalStakeRemaining = amountOfPrincipalStake - _claimedPrincipalFunds;

            if (_fundsToBeDistributed >= BALANCE_CLASSIFICATION_THRESHOLD && principalStakeRemaining > 0) {
                if (_fundsToBeDistributed > principalStakeRemaining) {
                // this means there is reward part of the funds to be
                // distributed
                _principalPayout = principalStakeRemaining;
                // shouldn't underflow
                _rewardPayout = _fundsToBeDistributed - principalStakeRemaining;
                } else {
                // this means there is no reward part of the funds to be
                // distributed
                _principalPayout = _fundsToBeDistributed;
                }
            } else {
                _rewardPayout = _fundsToBeDistributed;
            }
        }

        {
            if (_fundsToBeDistributed > type(uint128).max) revert InvalidDistribution_TooLarge();
            // Write to storage
            // the principal value
            // it cannot overflow because _principalPayout < _fundsToBeDistributed
            if (_principalPayout > 0) claimedPrincipalFunds += uint128(_principalPayout);
        }
        {
            /// interactions
            
            // pay outs
            // earlier tranche recipients may try to re-enter but will cause fn to
            // revert
            // when later external calls fail (bc balance is emptied early)
        
            // pay out principal
            _payout(principalRecipient, _principalPayout, pullFlowFlag);
            // pay out reward
            _payout(rewardRecipient, _rewardPayout, pullFlowFlag);

            if (pullFlowFlag == PULL) {
                if (_principalPayout > 0 || _rewardPayout > 0) {
                    // Write to storage
                    fundsPendingWithdrawal = uint128(_memoryFundsPendingWithdrawal + _principalPayout + _rewardPayout);
                }
            }
        }

        emit DistributeFunds(_principalPayout, _rewardPayout, pullFlowFlag);
    }

}