# Known Issues

This document lists findings that have already been submitted and reviewed for the `obol-splits` contracts (OVM, OWR, OTR, and ObolLidoSplit). Every item below has been evaluated by the Obol Security Team and is either resolved, accepted as a design trade-off, or determined not to be a vulnerability.

**Please do not resubmit these findings or close variants of them.** Duplicate submissions will not be eligible for a reward.

Many of these findings relate to the privileges of trusted roles. Before submitting a report, please review the documented [role risks and trust assumptions](https://docs.obol.org/next/learn/readme/obol-splits#role-risks-and-trust-assumptions) — behavior that falls within these assumptions is not considered a vulnerability.

If you believe you have found a new, distinct issue, please report it to the Obol Security Team at [security@obol.tech](mailto:security@obol.tech).

## Reentrancy & Accounting

* **Cross-function PUSH→PULL reentrancy (OWR/OTR):** A malicious `principalRecipient` could trigger `distributeFundsPull()` during a `distributeFunds()` (PUSH) operation, creating unbacked pull balances. The principal recipient is trusted at deployment, and the OVM architecture mitigates this scenario.
* **Arithmetic underflow DoS (OVM/OWR):** A claim that a permissionless attacker could brick distribution via arithmetic underflow by manipulating contract balances. The PUSH distribution logic preserves its accounting invariants.
* **Principal vs reward classification threshold (OVM/OWR/OTR):** These contracts cannot tell principal from rewards on-chain, so they classify each distribution by size. When the undistributed balance is at least the classification threshold, it is paid to the principal recipient up to the outstanding principal, and the rest goes to the reward recipient; a smaller balance goes entirely to the reward recipient. The threshold is `principalThreshold` on the OVM (set per instance at deployment, in gwei), a fixed 16 ether `BALANCE_CLASSIFICATION_THRESHOLD` on the OWR, and a `BALANCE_CLASSIFICATION_THRESHOLD` set per factory on the OTR. Inflows below the threshold, such as routine reward sweeps, donations, or EIP-7002 partial withdrawals requested by a `WITHDRAWAL_ROLE` holder, are treated as rewards by design, and a balance that a donation pushes across the threshold is treated as principal in the same way. This is the documented [principal threshold](https://docs.obol.org/next/learn/readme/obol-splits#what-is-the-principal-threshold-for) heuristic, not a vulnerability; pushing a balance across the threshold requires sending the contract ether that is itself paid out to the recipients.
* **OTR threshold not validated against token decimals:** `OptimisticTokenWithdrawalRecipientFactory` fixes one `BALANCE_CLASSIFICATION_THRESHOLD` for every clone it creates when the factory is deployed, and neither the factory nor `createOWRecipient()` checks that threshold, or the principal amount, against the decimals of the chosen token. Using a factory whose threshold suits the token is the deployer's responsibility.

## Access Control & Roles (OVM)

* **`setAmountOfPrincipalStake()` role assignment:** The function is gated by `SET_BENEFICIARY_ROLE` rather than a dedicated role. Parties trusted with `SET_BENEFICIARY_ROLE` are already trusted with fund routing, so no new trust boundary is crossed.
* **`withdrawPullBalance()` access control:** The function is intentionally permissionless — it sends funds only to their rightful owner and follows the checks-effects-interactions pattern.
* **`sweep()` asymmetry:** `sweep()` can redirect principal pull balances to arbitrary addresses and has no equivalent path for the reward recipient. Redirection is an intended owner capability; reward recipients withdraw via `withdrawPullBalance()`.
* **`consolidate()` and recipient updates:** `consolidate()`, `setBeneficiary()`, `setRewardRecipient()` and `setAmountOfPrincipalStake()` are restricted to the owner or the matching role (`CONSOLIDATION_ROLE`, `SET_BENEFICIARY_ROLE`, `SET_REWARD_ROLE`). That these can move stake or redirect future payouts is the documented power of those roles, not a vulnerability.

## Other Logic & Implementation (OVM/OWR)

* **`transfer()` role retention:** `ObolValidatorManager.transfer()` does not revoke operator roles after an ownership handoff. Revoking roles as part of a handoff is an operational responsibility of the owner.
* **`transferOwnership()` role retention:** Transferring ownership does not reset roles granted by the previous owner. This is accepted behavior — the new owner is expected to review and adjust role assignments after the handoff.
* **`deposit()` credential validation:** `deposit()` forwards the supplied `withdrawal_credentials` to the deposit contract without checking that they point to the OVM, and adds `msg.value` to `amountOfPrincipalStake`. Only the owner or a `DEPOSIT_ROLE` holder can call it, the ether deposited is the caller's own, and it cannot move ether the OVM already holds. A deposit to a validator that does not withdraw to the OVM therefore inflates the principal accounting and skews future principal-versus-reward classification, which is a documented `DEPOSIT_ROLE` trust assumption. Checking credentials on-chain would not remove this, because a validator's withdrawal credentials are fixed by its first deposit, which can be made directly to the deposit contract.
* **`sweepToBeneficiaryContract()` reverting:** This interface method always reverts. This is intentional and required for TVS interface conformance.
* **`withdrawPullBalance()` missing `nonReentrant` modifier:** The function follows the checks-effects-interactions pattern, which makes a reentrancy guard unnecessary.
* **`recoverFunds()` ETH handling (OVM/OWR):** `recoverFunds()` recovers ERC20 tokens only; passing `address(0)` for ETH reverts, because it is handled as an ERC20 balance query. This is intended: ETH is the asset these contracts distribute, so any ETH they hold, including accidental transfers, is paid out by `distributeFunds()` rather than recovered, and no ETH is stranded.
* **Excess fee refunds (OVM):** `consolidate()` and `withdraw()` refund unused `msg.value` to the caller-supplied `excessFeeRecipient` without validating it, so passing `address(0)` burns the refund. If the refund transfer fails, an `UnsentExcessFee` event is emitted and the ether stays in the OVM, where it is distributed like any other balance. Only the owner or a role holder can reach this path, and only with ether they supplied.

## Clone Implementations (OWR/OTR/ObolLidoSplit)

* **Calling implementation contracts directly:** OWR, OTR and ObolLidoSplit clones read their configuration (recipients, token, recovery address, split wallet) from immutable arguments that the clone appends to calldata. The implementation contracts have no guard against being called directly, so a caller can supply arbitrary arguments to them. Implementations hold no funds and share no state with any clone, so this cannot affect deployed clones; only clones are funded.

## ObolLidoSplit

* **`distribute()` reverts with no stETH balance:** `distribute()` wraps the contract's entire stETH balance, and wstETH rejects wrapping zero, so the call reverts while the contract holds no stETH, even if it holds wstETH. This is a liveness edge case with no loss of funds; `distribute()` succeeds once the contract holds stETH again.
