// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {StateProofVerifierV1} from "src/symbiotic/StateProofVerifierV1.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";

abstract contract SymPodStorageV1 is ERC4626, StateProofVerifierV1, Initializable {

    /// @dev hardfork it supports
    string public HARDFORK;

    /// @dev Address that receives rewards
    address public withdrawalAddress;

    /// @dev Address to recover tokens to
    address public recoveryAddress;
}