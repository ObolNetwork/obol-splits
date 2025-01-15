# Distributed Validator Depositor TODO

## Core Implementation Tasks

### Beacon Chain Integration 
- [x] Add interface for beacon chain deposit contract (`src/interfaces/IBeaconDeposit.sol`)
- [x] Implement deposit data generation for validators (`src/depositor/DistributedValidatorDepositor.sol`)
- [x] Add function to trigger beacon chain deposits when target amount reached (`src/depositor/DistributedValidatorDepositor.sol#submitDeposits`)
- [x] Add validation for deposit parameters (`src/depositor/DistributedValidatorDepositor.sol#setValidatorKeys`)
- [x] Add events for beacon chain deposit tracking (`src/interfaces/IDistributedValidatorDepositor.sol#BeaconDeposit`)

### Withdrawal Integration 
- [x] Add interface for withdrawal split contract (`src/interfaces/IValidatorWithdrawalSplit.sol`)
- [x] Link depositor shares to withdrawal split proportions (`src/depositor/DistributedValidatorDepositor.sol#setWithdrawalSplit`)
- [x] Implement withdrawal credentials pointing to split contract (`src/depositor/DistributedValidatorDepositor.sol#setWithdrawalSplit`)
- [x] Add validation to ensure withdrawal split matches deposit shares (`src/depositor/DistributedValidatorDepositor.sol#setWithdrawalSplit`)
- [x] Implement withdrawal split contract (`src/splits/ValidatorWithdrawalSplit.sol`)
  - [x] Share management (`src/splits/ValidatorWithdrawalSplit.sol#initialize`)
  - [x] ETH distribution (`src/splits/ValidatorWithdrawalSplit.sol#_distributeToOperators`)
  - [x] Fee handling (`src/splits/ValidatorWithdrawalSplit.sol#_beforeDistribute`)
- [x] Create withdrawal split factory (`src/splits/ValidatorWithdrawalSplitFactory.sol`)
  - [x] Split creation (`src/splits/ValidatorWithdrawalSplitFactory.sol#createSplit`)
  - [x] Fee configuration (`src/splits/ValidatorWithdrawalSplitFactory.sol#constructor`)

### Deposit Management 
- [x] Add operator-only deposit restriction (`src/depositor/DistributedValidatorDepositor.sol#_verifyOperator`)
- [x] Add per-operator deposit tracking (`src/depositor/DistributedValidatorDepositor.sol#operatorDeposits`)
- [x] Add deposit share enforcement (`src/depositor/DistributedValidatorDepositor.sol#deposit`)
- [x] Add view functions for deposit tracking
  - [x] Get operator deposit (`src/depositor/DistributedValidatorDepositor.sol#getOperatorDeposit`)
  - [x] Get operator max deposit (`src/depositor/DistributedValidatorDepositor.sol#getOperatorMaxDeposit`)
- [x] Add operator withdrawal function (`src/depositor/DistributedValidatorDepositor.sol#withdrawDeposit`)

### Testing
- [ ] Write unit tests for DistributedValidatorDepositor
  - [ ] Test initialization
  - [ ] Test deposit logic
    - [ ] Test operator-only deposits
    - [ ] Test deposit share limits
    - [ ] Test deposit tracking
    - [ ] Test deposit withdrawals
  - [ ] Test share calculations
  - [ ] Test deposit limits
  - [ ] Test operator validation
  - [ ] Test validator key setting
  - [ ] Test beacon chain deposits
  - [ ] Test withdrawal split integration
- [ ] Write unit tests for DistributedValidatorDepositorFactory
  - [ ] Test depositor creation
  - [ ] Test initialization parameters
  - [ ] Test beacon deposit address validation
- [ ] Write unit tests for ValidatorWithdrawalSplit
  - [ ] Test initialization
  - [ ] Test share calculations
  - [ ] Test ETH distribution
  - [ ] Test fee handling
- [ ] Write integration tests
  - [ ] Test full deposit flow
  - [ ] Test beacon chain integration
  - [ ] Test withdrawal split integration
- [ ] Add fuzzing tests for edge cases
- [ ] Add invariant tests for security properties

### User Interface
- [x] Add view functions for contract state
  - [x] Get target amount (`src/depositor/DistributedValidatorDepositor.sol#getTargetAmount`)
  - [x] Get remaining amount (`src/depositor/DistributedValidatorDepositor.sol#getRemainingAmount`)
  - [x] Get operator share (`src/depositor/DistributedValidatorDepositor.sol#getOperatorShare`)
  - [x] Check completion status (`src/depositor/DistributedValidatorDepositor.sol#isComplete`)
- [x] Add detailed events for frontend integration
  - [x] Operator deposit (`src/interfaces/IDistributedValidatorDepositor.sol#OperatorDeposit`)
  - [x] Deposit complete (`src/interfaces/IDistributedValidatorDepositor.sol#DepositComplete`)
  - [x] Validator keys set (`src/interfaces/IDistributedValidatorDepositor.sol#ValidatorKeysSet`)
  - [x] Beacon deposit (`src/interfaces/IDistributedValidatorDepositor.sol#BeaconDeposit`)
  - [x] Operator withdraw (`src/depositor/DistributedValidatorDepositor.sol#OperatorWithdraw`)
- [x] Add operator deposit progress tracking
  - [x] Track individual deposits (`src/depositor/DistributedValidatorDepositor.sol#operatorDeposits`)
  - [x] Track max deposits (`src/depositor/DistributedValidatorDepositor.sol#getOperatorMaxDeposit`)

### External Contracts
- [x] Define interface requirements for beacon chain deposit contract (`src/interfaces/IBeaconDeposit.sol`)
  - [x] Deposit function (`src/interfaces/IBeaconDeposit.sol#deposit`)
  - [x] View functions (`src/interfaces/IBeaconDeposit.sol#get_deposit_root`, `get_deposit_count`)
- [x] Define interface requirements for withdrawal split contract (`src/interfaces/IValidatorWithdrawalSplit.sol`)
  - [x] Share management (`src/interfaces/IValidatorWithdrawalSplit.sol#initialize`)
  - [x] Distribution (`src/interfaces/IValidatorWithdrawalSplit.sol#distribute`)
  - [x] View functions (`src/interfaces/IValidatorWithdrawalSplit.sol#getOperatorShare`, `getOperators`)
- [ ] Document integration points
- [ ] Add validation for contract interactions

## Contract Flow

1. Deploy withdrawal split factory with fee settings
   ```solidity
   ValidatorWithdrawalSplitFactory splitFactory = new ValidatorWithdrawalSplitFactory(feeRecipient, feeShare);
   ```

2. Deploy depositor factory with beacon deposit address
   ```solidity
   DistributedValidatorDepositorFactory depositorFactory = new DistributedValidatorDepositorFactory(beaconDepositAddress);
   ```

3. Create depositor and withdrawal split
   ```solidity
   address depositor = depositorFactory.createDepositor(validatorCount, operators, shares);
   address split = splitFactory.createSplit(operators, shares);
   ```

4. Set withdrawal split and deposit ETH (operator-only)
   ```solidity
   DistributedValidatorDepositor(depositor).setWithdrawalSplit(split);
   // Each operator must deposit their share (e.g., 8 ETH for 25%)
   DistributedValidatorDepositor(depositor).deposit{value: 8 ether}();
   ```

5. Set validator keys and submit deposits
   ```solidity
   DistributedValidatorDepositor(depositor).setValidatorKeys(index, pubkey, signature, depositDataRoot);
   DistributedValidatorDepositor(depositor).submitDeposits();
   ```

6. Withdrawals automatically go to split contract and are distributed according to shares
   ```solidity
   ValidatorWithdrawalSplit(split).distribute();
   ```
