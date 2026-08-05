![Obol Logo](https://obol.tech/obolnetwork.png)

<h1 align="center">Obol Splits</h1>

This repo contains Obol Splits smart contracts. This suite of smart contracts and associated tests are intended to serve as a public good to enable the safe and secure creation of Distributed Validators for Ethereum Consensus-based networks.

### Disclaimer

The following smart contracts are provided as is, without warranty. Details of their audit can be consulted [here](https://docs.obol.org/docs/advanced-and-troubleshooting/security/overview).

## Role Risks & Trust Assumptions

The Obol Validator Manager (OVM) uses standard role-based access control, with roles granted by the owner via `grantRoles()`. **Several roles are more privileged than their names suggest** — granting one extends real trust to the address that holds it. The OVM is non-custodial and has no upgrade path or admin override beyond its owner, so a malicious or compromised role holder can act up to the limit of their role and nobody can stop them mid-transaction. Grant roles narrowly, prefer multi-sigs over externally owned accounts (EOAs) for any privileged address, and revoke roles you no longer need with `revokeRoles()`. A single address holding several roles, or whose key is later compromised, combines the risks below.

- **`CONSOLIDATION_ROLE` — can steal the entire stake.** [EIP-7251](https://eips.ethereum.org/EIPS/eip-7251) does not require a consolidation's source and target validators to share withdrawal credentials; it only requires the target to be a compounding (0x02) validator. The `consolidate()` method does not restrict the target to validators managed by this contract, so a malicious holder can consolidate the OVM's validators into an external 0x02 validator that they control, moving all principal and reward balances out of the OVM's reach. This is the most dangerous role to grant.
- **`SET_BENEFICIARY_ROLE` — can redirect returned principal.** Setting the beneficiary to an attacker-controlled address sends all principal returned on the next exit, or above-threshold withdrawal, to that address. The same role can change `amountOfPrincipalStake` via `setAmountOfPrincipalStake()`, distorting the principal-versus-reward accounting to misclassify funds in either direction.
- **`SET_REWARD_ROLE` — can redirect accrued rewards.** Setting the reward recipient to an attacker-controlled address sends all rewards to that address the next time `distributeFunds()` is called, which anyone can do. In the misclassification edge cases of the optimistic accounting, this can also capture ether that was really principal.
- **`WITHDRAWAL_ROLE`** — cannot send funds to an external address, because withdrawals always return to the OVM, whose address is committed to in the validators' withdrawal credentials. It can, however, **force-exit every validator**, taking the cluster offline and locking funds in the exit queue for days. By choosing withdrawal amounts above or below the `principalThreshold`, a holder can also influence whether withdrawn ether is later treated as principal or reward, shifting value between the beneficiary and the reward recipient.
- **`RECOVER_FUNDS_ROLE` — can drain any ERC20 token** held by the contract to an arbitrary address. This does not touch the staked ETH, the principal, or the rewards, which are all native ETH rather than ERC20, but any tokens that arrive at the contract — airdrops, liquid staking tokens, or accidental transfers — can be taken.
- **`DEPOSIT_ROLE` — can distort the principal accounting.** `deposit()` does not validate the supplied withdrawal credentials, so a malicious holder can register validators whose credentials point outside the OVM, or whose signing keys they control. The depositor spends their own ether and cannot withdraw the contract's existing funds, but every deposit increases `amountOfPrincipalStake`, so depositing to validators that never return their principal to the OVM inflates the principal accounting and skews the principal-versus-reward split.

The `owner` is the most powerful actor of all. The owner passes every permission check without holding any role, and additionally controls owner-only functions such as `transfer()` and the ownership handover flow. A malicious or compromised owner can therefore do everything listed above — steal principal and rewards, drain tokens, and force-exit validators. Treat the owner as the contract's master key: use a high-threshold multi-sig such as a [SAFE](https://safe.global), or assign fine-grained roles and then call [`renounceOwnership()`](https://github.com/vectorized/solady/blob/main/src/auth/Ownable.sol#L186) so that no single key retains full control. Because the owner holds such significant control over the contract's funds, operators should only run validators for customers they trust.

> [!WARNING]
> **Deposit front-running.** A validator's withdrawal credentials are fixed by the **first** deposit submitted for its public key. Every later deposit for that key is treated as a top-up, and its withdrawal credentials are ignored by the consensus layer. The `deposit()` method does not validate the withdrawal credentials it submits, and it cannot detect or prevent a deposit made directly to the Ethereum deposit contract for the same public key beforehand.
>
> Creating a validator with a different withdrawal address requires its signing key, which for a Distributed Validator means a colluding threshold of its operators. Such operators could create the validator first, pointing its withdrawal address outside the OVM, so that the OVM's later deposit only tops up a validator whose principal exits beyond the contract's reach. No on-chain check can remove this property of the Ethereum deposit mechanism; it falls under the same trust assumption as the rest of the contract — **only deposit to validators whose keys were generated by operators you trust.**

For the full role reference and the principal-versus-reward accounting model, see the [Obol Validator Manager documentation](https://docs.obol.org/docs/learn/introduction/obol-splits).

## Quickstart

This repo is built with [foundry](https://github.com/foundry-rs/foundry), a rust-based solidity development environment, and relies on [solmate](https://github.com/Rari-Capital/solmate), an efficient solidity smart contract library. Read the docs on our [docs site](https://docs.obol.org/docs/learn/introduction/obol-splits) for more information on what Distributed Validators are, and their smart contract lifecycle.

### Installation

Follow the instructions here to install [foundry](https://github.com/foundry-rs/foundry#installation).

Then install the contract dependencies:

```sh
forge install
```

### Local Development

To test your changes to the codebase run the unit tests with:

```
cp .env.sample .env
```

```sh
forge test
```

This command starts runs all tests.

> NOTE: To run a specific test:
```sh
forge test --match-contract ContractTest --match-test testFunction -vv
```

### Build

To compile your smart contracts and generate their ABIs run:

```sh
forge build
```

This command generates compilation output into the `out` directory.

### Deployment

This repo can be deployed with `forge create` or running the deployment scripts.

#### Create a new Lido Split

To create a new Lido Splitter, setup your environment variables (`cp .env.sample .env` and ajust as needed) and then `source .env` to load them, then run the following command:

```sh
forge script script/ObolLidoSetupScript.sol:ObolLidoSetupScript --fork-url $RPC_URL -vvvv --sig "run(string,address,address)" "./script/data/lido-data.json" $SPLITMAIN $OBOL_LIDO_SPLIT_FACTORY
```

> [!TIP]
> The above is setup as a dry-run, you must add `--broadcast` to the end of the command for the transaction to be sent to the network.

#### Hoodi

ObolValidatorManagerFactory: https://hoodi.etherscan.io/address/0x5754C8665B7e7BF15E83fCdF6d9636684B782b12

#### Sepolia

ObolValidatorManagerFactory: https://sepolia.etherscan.io/address/0xF32F8B563d8369d40C45D5d667C2B26937F2A3d3

OptimisticWithdrawalRecipientFactory: https://sepolia.etherscan.io/address/0xca78f8fda7ec13ae246e4d4cd38b9ce25a12e64a

OptimisticWithdrawalRecipient: https://sepolia.etherscan.io/address/0x99585e71ab1118682d51efefca0a170c70eef0d6

#### Mainnet

ObolValidatorManagerFactory: https://etherscan.io/address/0x2c26B5A373294CaccBd3DE817D9B7C6aea7De584

OptimisticWithdrawalRecipientFactory: https://etherscan.io/address/0x119acd7844cbdd5fc09b1c6a4408f490c8f7f522

OptimisticWithdrawalRecipient: https://etherscan.io/address/0xe11eabf19a49c389d3e8735c35f8f34f28bdcb22

ObolLidoSplitFactory: https://etherscan.io/address/0xA9d94139A310150Ca1163b5E23f3E1dbb7D9E2A6

ObolLidoSplit: https://etherscan.io/address/0x2fB59065F049e0D0E3180C6312FA0FeB5Bbf0FE3

### Versioning

Releases of this repo constitute post-fix review, audited commits. Consult the release notes and audits as not all contracts are in scope each audit.
