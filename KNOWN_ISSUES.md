# Known Issues

This document lists findings that have already been submitted and reviewed for the `obol-splits` contracts (OVM, OWR, and OTR). Every item below has been evaluated by the Obol Security Team and is either resolved, accepted as a design trade-off, or determined not to be a vulnerability.

**Please do not resubmit these findings or close variants of them.** Duplicate submissions will not be eligible for a reward.

Many of these findings relate to the privileges of trusted roles. Before submitting a report, please review the documented [role risks and trust assumptions](https://docs.obol.org/next/learn/readme/obol-splits#role-risks-and-trust-assumptions) — behavior that falls within these assumptions is not considered a vulnerability.

If you believe you have found a new, distinct issue, please report it to the Obol Security Team at [security@obol.network](mailto:security@obol.network).

## Reentrancy & Accounting

* **Cross-function PUSH→PULL reentrancy (OWR/OTR):** A malicious `principalRecipient` could trigger `distributeFundsPull()` during a `distributeFunds()` (PUSH) operation, creating unbacked pull balances. The principal recipient is trusted at deployment, and the OVM architecture mitigates this scenario.
* **Arithmetic underflow DoS (OVM/OWR):** A claim that a permissionless attacker could brick distribution via arithmetic underflow by manipulating contract balances. The PUSH distribution logic preserves its accounting invariants.

## Access Control & Roles (OVM)

* **`setAmountOfPrincipalStake()` role assignment:** The function is gated by `SET_BENEFICIARY_ROLE` rather than a dedicated role. Parties trusted with `SET_BENEFICIARY_ROLE` are already trusted with fund routing, so no new trust boundary is crossed.
* **`withdrawPullBalance()` access control:** The function is intentionally permissionless — it sends funds only to their rightful owner and follows the checks-effects-interactions pattern.
* **`sweep()` asymmetry:** `sweep()` can redirect principal pull balances to arbitrary addresses and has no equivalent path for the reward recipient. Redirection is an intended owner capability; reward recipients withdraw via `withdrawPullBalance()`.

## Other Logic & Implementation (OVM/OWR)

* **`transfer()` role retention:** `ObolValidatorManager.transfer()` does not revoke operator roles after an ownership handoff. Revoking roles as part of a handoff is an operational responsibility of the owner.
* **`deposit()` credential validation:** `deposit()` accepts arbitrary `withdrawal_credentials`, which can inflate internal accounting.
* **`sweepToBeneficiaryContract()` reverting:** This interface method always reverts. This is intentional and required for TVS interface conformance.
* **`withdrawPullBalance()` missing `nonReentrant` modifier:** The function follows the checks-effects-interactions pattern, which makes a reentrancy guard unnecessary.
* **`recoverFunds()` ETH handling:** The ETH path of fund recovery does not behave as expected.
