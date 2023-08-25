**Issue category**
High

**Issue title**
[HIGH 1] Funds can get locked up due to incorrect calculation of will deadline.

**Where**
In the `createTrust` function in Trustee.sol on [line 145](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L145)

**Impact**
The incorrect calculation results in a deadline extending far into the future, which would prevent beneficiaries from withdrawing their funds at any point in their lifetime. For example, a period of 1 hour (3600 seconds), would incorrectly set the deadline to a time in the year 2163.

**Description**
The calculation of the will deadline multiplies '*' instead of adds '+' the `period` to the current `block.timestamp`.

**Recommendations to fix**
Change the '+' to a '*' so the line looks like this:
```uint256 _deadline = block.timestamp * periodInSecs(_period);```

**Additional context**
This impacts all users during trust creation.

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
High

**Issue title**
[HIGH 2] Beneficiary funds are locked forever when initial payout is not the full payout

**Where**
In the `bulkTransfers` function in Trustee.sol on [line 237](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L237)

**Impact**
Beneficiaries who only get a partial payout during the call to `bulkTransfers` are no longer able to access the remainder of the payout owed to them.

**Description**
At the end of the `bulkTransfers` function, the will is marked as no longer being active, `active = false`. However, it is possible that during the beneficiary payouts that are done in `transferHelper`, some or all of the beneficiaries are not fully paid out. For example, this can happen when the will owner has not set enough allowance to the trustee contract to payout the ERC20 tokens.

**Recommendations to fix**
Consider returning a boolean from `transferHelper` that indicates if the transfer was complete (`true`), or zero or partial (`false`). Within `bulkTransfers`, track every return value from `transferHelper` and if none return a `false`, then mark the will as `active = false`. Otherwise, if any are returned as `false`, then the will must remain active.

**Additional context**
This issue does not exist when the payout is completed in full on the initial call to `bulkTransfers` for this will.

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
High

**Issue title**
[HIGH 3] Beneficiary can get funds stuck if they are not fully paid out on initial payout

**Where**
In the `transferHelper` function in Trustee.sol on [line 256](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L256)

**Impact**
A beneficiary may only end up receiving a partial payout, with no ability to receive the remainder of what they are owed.

**Description**
The `transferHelper` function always concludes with marking the current beneficiary as being credited.

```beneficiaryData[_willOwner][_beneficiaryIndex].credited = true;```

This does not account for a scenario where the amount owed to the beneficiary is the amount they received.

**Recommendations to fix**
Set `credited = true` within each of the types of payouts.

For NFT payouts, set this to true right after the `IERC721.safeTransferFrom` call. There are no partial ERC721 payouts; if the transfer succeeds, the beneficiary has been fully credited.

For ERC20 payouts, compare the `value` returned from `getEntitlementOnDeath` to what is owed to the beneficiary. Since `beneficiary.value` represents a percentage of the payout, this check would look like this:

```value >= (benificiary.value * erc20.balanceOf(willOwner))/100```

**Additional context**
This impacts any beneficiary receiving an ERC20 payout when the full amount is not paid out on the initial call to `transferHelper` for the beneficiary.

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
High

**Issue title**
[HIGH 5] Incorrect calculation of amount of ERC20 owed to beneficiary

**Where**
In the `getEntitlementOnDeath` function in Trustee.sol on [line 299](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L299)

**Impact**
Beneficiary may not be able to withdraw their payout due to the incorrect calculation exceeding the will owner's balance of ERC20. The beneficiary will not be able to withdraw their funds until the will owner's balance is increased to be at least equal to the allowance they have made to the trustee contract.

**Description**
In cases where the allowance is greater than the ERC20 balance, the code calculates the payout amount based on the percentage of the allowance, `amount * value`. The calculation should instead be done against the will owner's ERC20 balance.

**Recommendations to fix**
Change the logic to:

```
  uint256 tokensOwed = (balance * value) / 100);
  return (tokensOwed > amount ? amount : tokensOwed);
```
**Additional context**
This applies to all ERC20 beneficiaries when the will owner's ERC20 balance is less than the allowance they have granted to the trustee contract.

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
High

**Issue title**
[HIGH 6] Precision loss could lead to beneficiary receiving less than they are owed

**Where**
In the `getEntitlementOnDeath` function in Trustee.sol on [line 301](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L301)

**Impact**
Beneficiary may receive less than they are owed, with no ability to ever receive the remainder

**Description**
When a user has a non-zero initialBalance, the calculation of the remaining owed ERC20 tokens is imprecise. As an example, if their `initialBalance` is 1, and the `beneficiary.value` is 50%, this will always return a 0 because of this calculation:

```(value * initialBalance) / 100)```

**Recommendations to fix**
Calculate the tokens the beneficiary is owed, and then deduct what they have already been paid out. The remainder is what should be considered to be  returned. Change the code to:

```
  uint256 tokensOwed = (balance * value) / 100);
  uint256 remainingOwed = tokensOwed - initialBalance;
  return (remainingOwed > amount ? amount : remainingOwed);
```

**Additional context**
Add any other context about the problem here.

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
High

**Issue title**
[HIGH 7] Beneficiary can have their funds stuck if they are owed more than the ERC20 allowance or the will owner's balance

**Where**
In the `getEntitlementOnDeath` function in Trustee.sol on [line 301](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L301)


**Impact**
Beneficiary may receive less than they are owed, with no ability to ever receive the remainder

**Description**
When a beneficiary is attempting to receive a payout, after already doing this once (meaning, they already have a non-zero `initialBalance`), the logic in `getEntitlementOnDeath` does not account for the will owner's ERC20 balance, or the allowance they have made to the trustee contract. This check *is* done for the [first repayment](https://github.com/ebaizel/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L297) but it also needs to be done for subsequent payments.

**Recommendations to fix**
In `getEntitlementOnDeath`, return the lower of these values:
* the ERC20 allowance the will owner has made to the trustee contract
* the remainingTokensOwned to the beneficiary, using this formula: ((willOwnerERC20Balance * beneficiaryValue) / 100) - initialBalance)

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Medium

**Issue title**
[MEDIUM 1]  Subscription price does not take into consideration the number of beneficiaries, or duration of the subscription

**Where**
In the `subscriptionCheck` modifier in Trustee.sol on [line 81](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L81)


**Impact**
Trustee contract earns less revenue than is expected

**Description**
When a subscription is paid, either during `createTrust` or `paySubscription`, there is no check for how long the subscription is created for, or for how many beneficiaries. Every user ends up paying the same amount.

**Recommendations to fix**
Change `subscriptionCheck` to be a function instead of a modifier, so that we can look up the number of beneficiaries, and ensure the correct amount is being sent in `msg.value`.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Medium

**Issue title**
[MEDIUM 2] Existing trust data can be included in a new trust if prior trust was not explicitly deleted after it became inactive

**Where**
In the `createTrust` function in Trustee.sol on [line 141](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L141)


**Impact**
Previous beneficiaries can be included in the new trust

**Description**
In `createTrust`, there is a check to ensure that no existing active trust exists for `msg.sender`. However, there is no assurance that `msg.sender` did not have any prior trust which is now inactive. Without this check, it leaves possible the case where a prior trusts' beneficiairies get included as the beneficiaries in the new trust.

**Recommendations to fix**
Ensure the trust is zero'ed out to start. This can be done in a couple of ways, such as verifying each field of the current trust is empty, or by simply calling deleteTrust() right after ensure no active trust exists for `msg.sender` on [line 142](https://github.com/ebaizel/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L142).

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Medium

**Issue title**
[MEDIUM 3] `addToMyTrustBeneficiaries` does not increment `trustData[msg.sender].beneficiaryCount` when adding new beneficiaries

**Where**
In the `addToMyTrustBeneficiaries` function in Trustee.sol on [line 178](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L178)

**Impact**
Beneficiaries added after the initial trust creation are not included in payouts done via `bulkTransfers`.

**Description**
`getMyTrustBeneficiaries` and `bulkTransfers` both contain loops that iterate over the `trustData[msg.sender].beneficiaryCount`. Therefore, beneficiaries added after the trust was initially created are not included in the returned data.

For the call to `bulkTransfers`, this means these beneficiaries are not included in the payout. They would still be able to collect their payout via `singleTransfer`.

**Recommendations to fix**
In `addToMyTrustBeneficiaries`, make sure to update the `trustData[msg.sender].beneficiaryCount` as new beneficiaries are added.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Medium

**Issue title**
[MEDIUM 4] Beneficiary payout accounting is incorrect for ERC20 payouts with multiple beneficiaries

**Where**
In the `getEntitlementOnDeath` function in Trustee.sol on [line 298](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L298)

**Impact**
Beneficiary does not receive the full ERC20 payout they are owed.

**Description**
On line 298, the beneficiary's `initialTokenBalance` is set to the lower amount of either the ERC20 allowance the will owner has made to the contract, or the will owner's ERC20 balance.

In the subsequent line, 299, the amount that is actually paid out to the user is calculated. This value should be the one set for the `initialTokenBalance`.

**Recommendations to fix**
First calculate the amount that is owed to the user. Next, set this value to the initialBalance, Then, return this value.

**Additional context**
This applies to any will where there are multiple ERC20 beneficiaries.

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 1] Unnecessary storage read

**Where**
In the `transfer` modifier in Trustee.sol on [line 67](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L67)

**Impact**
Users must pay unnecessary extra gas for a storage lookup that is not needed.

**Description**
The `msg.sender`'s trust is looked up on this line

```Trust memory trust = trustData[msg.sender];```

but it is never read after that.

**Recommendations to fix**
Remove this lookup.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 2] Anti-pattern when calling another contract

**Where**
In the `transfer` modifier in Trustee.sol on [line 72](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L72)

**Impact**
Because this call is made in the modifier, it opens up the opportunities for a re-entrancy attack by a malcious automator, where they re-enter before any state has been set.

**Description**
The recommended approach for calling other contracts is using the checks-effects-interaction pattern. In this pattern, the interaction is the final step, which in this case would be the payout. First ensure any checks have been made, and state updates have been made, and then call the contract.

**Recommendations to fix**
Move the payment call to a separate, non-re-entrant function, and call that at the end of the overall transaction.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 3] Inaccurate error message in transfer modifier for subscription payments

**Where**
In the `transfer` modifier in Trustee.sol on [line 77](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L77)

**Impact**
Integrators and users may be misled by any errors they receive related to insufficient funds.

**Description**
The error message indicates "Insufficient funds to create trust", however, the `transfer` modifier is also called from `paySubscription`, in which case that message is inaccurate.

**Recommendations to fix**
Update the message to something generic, such as "Insufficient funds for operation"

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 4] Period durations are inaccurate for periods beyond 1 week

**Where**
In the `periodInSecs` function in Trustee.sol on [line 101](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L101)

**Impact**
Period duration assumptions made by users may be inaccurate.

**Description**
There is a loss in fidelity once you get into the months and year. For example, the Year equates to 336 days.

**Recommendations to fix**
Consider using 30 days for 1 month, which would give more accurate seconds counts. Also, consider adding a comment for periods larger that `1 weeks` to indicate the period they represent, eg `1 month`.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 5] Public functions not called internally should be made external

**Where**
In the `trustStatus` function in Trustee.sol on [line 128](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L128)

**Impact**
Users pay more gas to call these functions than if they were made external

**Description**
Because of how the EVM processes `public` functions compared to `external` functions, it costs more gas to call a `public` function. The benefit of a `public` function is that it can be called from within the contract, whereas an `external` function can not.

However, there are a few functions in `Trustee.sol` that do not need to be `public`, and these should be updated to `external`.

**Recommendations to fix**
Update these functions to be `external`:
* trustStatus
* deleteTrust
* updateMyTrustBeneficiaries
* addToMyTrustBeneficiaries
* getMyTrustBeneficiaries
* getApprovedTokens
* bulkTransfers
* singleTransfer
* withdraw

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 6] `addToMyTrustBeneficiaries` should calculate new subscription fees, and be `payable`

**Where**
In the `addToMyTrustBeneficiaries` function in Trustee.sol on [line 178](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L178)

**Impact**
The `Trustee` contract loses out on revenue by not charging users for beneficiaries

**Description**
Based on the `pricePerBeneficiary` variable, it would seem that part of this contract's revenue stream is by charging users based on how many beneficiaries they have on their will.

When a user adds beneficiaries to their trust, they should be expected to pay for the additional beneficiaries. However, this is not being done, and users pay the same regardless of how many beneficiaries they add.

**Recommendations to fix**
Make `addToMyTrustBeneficiaries` a `payable` function so that users can send value to this contract. Then, calculate how much additional subscription fee they should pay based on the number of new beneficiaries, multiplied by the `pricePerBeneficiary`, and ensure they have sent at least this amount in `msg.value`.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 7] Ensure subscription price and per-beneficiary price are non-zero

**Where**
In the `setSubcriptionPrice` function in Trustee.sol on [line 216](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L216), and in `setPricePerBeneficiary` on [line 221](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L221)

**Impact**
Owner may mistakenly set the subscription price to zero 

**Description**
There is no check for the `_price` that is being passed in. Unless there is a need to have free subscriptions, there should be a check that this is a non-zero value.

**Recommendations to fix**
Add a line such as:
```require(_price > 0, "Subscription price must be greater than 0")``` at the top of each of these two functions

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 8] Unneeded setter consumes extra gas

**Where**
In the `setSubcriptionPrice` function in Trustee.sol on [line 217](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L217), and in `setPricePerBeneficiary` on [line 222](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L222)

**Impact**
Owner pays extra gas unnecessarily when they set either of the prices

**Description**
In both methods, the price is initially set to `0.0001 ether` before it is set to the value passed in. This initially setting isn't needed as it is immediately being overwritten, causing an unnecessary computation and costing extra gas.

**Recommendations to fix**
Remove the lines that set the value to `0.0001 ether`.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 9] Remove `creditBeneficiary` modifier from `bulkTransfers` and `singleTransfer` since they both call `transferHelper`, and it is already called there

**Where**
In the `bulkTransfers` function in Trustee.sol on [line 232](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L232), and in `singleTransfer` on [line 241](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L241)

**Impact**
Users pay extra gas for the same check to be done twice.

**Description**
Both methods call the `creditBeneficiary` modifier, before they call `transferHelper` which itself calls `creditBeneficiary`. This can be reduced to a single invocation of this modifier to save gas.

**Recommendations to fix**
Remove the `creditBeneficiary` modifier from the two functions, and just keep it on `singleTransfer`

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 10] `TransferToBeneficiary` should only be emitted if a transfer actually occurred

**Where**
In the `transferHelper` function in Trustee.sol on [line 245](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L245)

**Impact**
Any system monitoring this contract may receive inaccurate data if `transferHelper` is called but no transfer occurs

**Description**
In `transferHelper` there is a check ```if (!beneficiary.credited) {``` to determine if the function should attempt to process a beneficiary payout. If this evalutes to false, the ```emit TransferToBeneficiary``` call on line 259 should not be called.

This is also true in the event that the NFT or the ERC20 transfer did not result in a transfer taking place.

**Recommendations to fix**
Move the ```emit TransferToBeneficiary``` call to within each of the NFT and the ERC20 payout code blocks, and only emit it if a transfer has taken place.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 11] `subscriptionCheck` modifier should come before `transfer` modifier so the transaction can revert early if `msg.value` is not sufficient

**Where**
In the `paySubscription` function in Trustee.sol on [line 264](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L264)

**Impact**
Minimize loss of gas in the revert scenario where user has not passed in sufficient `msg.value` for the subscription

**Description**
Because the `transfer` modifier is called first, a payout is made to the `automator` *prior to* determining if the `msg.value` sent in is sufficient for the subscription. In the event it wasn't, the transaction reverts and unused gas is returned to the caller.

However, this is suboptimal for the user, because swapping the sequence of modifier calls would mean the transaction immediately reverts upon an insufficient `msg.value` and no external call for the payout is made.

**Recommendations to fix**
Move the `subscriptionCheck` modifier ahead of the `transfer` modifier in the `paySubscription` function 

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 12] Parameters sent to emitting of `Subscriptions` event are in incorrect order

**Where**
In the `subscribe` function in Trustee.sol on [line 274](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L274)

**Impact**
Monitoring systems will incorrectly parse this event

**Description**
The Subscriptions event takes three parameters in this order: owner, period, price. The emitting of this event sends the parameters in this order: owner, price, period.

**Recommendations to fix**
Rearrange the parameters to match the order defined in the event.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 13] Missing validation to ensure `end` parameter is <= `subscriptionData.length`

**Where**
In the `getSubscriptions` function in Trustee.sol on [line 282](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L282)

**Impact**
Caller may not know that some of the data that is returned references a non-existent subscription, and this consumes unnecessary gas.

**Description**
If `end` is set to say 100, but there are only 5 subscriptions, the function will return many empty subscriptions for non-existent subscriptions.

**Recommendations to fix**
Add a `require` check at the top of the function to ensure `end <= subscriptionData.length`

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 14] Solidity version should be pinned to a specific version to prevent unexpected changes in behavior in newer versions of Solidity

**Where**
In Trustee.sol on [line 2](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L2)

**Impact**
Future versions of Solidity may introduce unexpected behavior in this contract, including vulernabilities or denial of service due to changes in gas fees for opcodes.

**Description**
For non-library contracts which are not designed to be extended or utilitized within other contracts, it is best practice to pin the Solidity version to ensure the behavior of the contract is fixed, and can not be impacted by future updates to Solidity.

**Recommendations to fix**
Pin the version to a 0.8 version that this contract has been fully tested. Recommendation is to start with a recent version like `0.8.19`, and if everything works correctly, then pin to that version.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Low

**Issue title**
[LOW 15] Save gas by keeping revert error message within 32 bytes

**Where**
In Trustee.sol on [line 77](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L77)

**Impact**
Consumes more gas for storage

**Description**
The revert message is stored in the contract storage, and the current message requires two storage slots as it exceeds 32 bytes. Trimming the message to 32 bytes would reduce the storage cost.

**Recommendations to fix**
Reword the message to something shorter such as `Need more funds to create trust`. Or something generic to also handle the case where this is for a subscription payment, such as `Insufficient funds sent`

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here


---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 1] Consider using Ownable2Step instead of Ownable

**Where**
In Trustee.sol on [line 8](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L8)

**Impact**
Improvement in security posture

**Description**
Consider using Ownable2Step (https://docs.openzeppelin.com/contracts/4.x/api/access#Ownable2Step) instead of Ownable to help defend against an unwanted ownership transfer, or transferring to an invalid address

**Recommendations to fix**
Trustee should extend from Ownable2Step instead of Ownable, and should take advantage of the two step process when transferring ownership to help safeguard against missteps.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 2] Pack structs for storage efficiency

**Where**
In Trustee.sol on [line 27](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L27)

**Impact**
Save on storage costs

**Description**
The Beneficiary struct is not optimally storing its contents. There are two `bool`s which each occupy a full slot, even though they only require 1 byte. If they are moved to follow one another, they can take advantage of the EVM which will allocate them both into the same storage slot, saving a storage slot of gas cost for the contract.

**Recommendations to fix**
Move the `credited` bool attribute to immediately follow the `isNFt` bool

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 3] Unused code

**Where**
In Trustee.sol on [line 64](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L64)

**Impact**
Unnecessary storage costs

**Description**
The `accumulator` variable is never read or used, and can be removed to save on storage costs.

Technically, this can also be said about `pricePerBeneficiary` since it is never used. However, it is set in `setPricePerBeneficiary` but evenso, the variable itself is never used in any calculations within the contract, so it should be removed along with that function. But, if there is a need to charge per beneficiary, then this should be kept.

**Recommendations to fix**
Remove the `accumulator` variable.
Check if the `pricePerBeneficiary` variable is needed, and remove it if not.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 4] Inaccurate `require` message

**Where**
In Trustee.sol on [line 81](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L81)

**Impact**
Caller may be misinformed on expected input value

**Description**
The require message states `"Amount should be equal to subscription Price"`. Technically, the amount should be greater than or equal to, and the message should be updated to reflect this.

**Recommendations to fix**
Update the message to say `"Amount should be at least equal to subscription Price"`

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 5] Include natspec comments to help developers and auditors understand the intended behavior of the code

**Where**
In Trustee.sol, throughout the code base

**Impact**
Decreases code clarity and increases chances that developers use the code in unintended ways

**Description**
Defining natspec for the codebase is a best practice that helps ensure developers and auditors can understand the intent of the code, and to verify that the code is in fact doing what is intended.

**Recommendations to fix**
Add natspec comments to all of the functions in the contract

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 6] Increment loop counter using assembly to save on gas

**Where**
In Trustee.sol on [line 147](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L147) and several other places

**Impact**
Unnecessary extra gas fees

**Description**
Incrementing the variable `i` within a for loop is cheaper when it is done in assembly.

**Recommendations to fix**
Increment `i` in assembly like this:
```
unchecked {
  i++;
}
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 7] Ensure _indexes.length == _beneficiaries.length

**Where**
In Trustee.sol on [line 170](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L170)

**Impact**
Caller is not protected against accidentally sending incorrect data

**Description**
If the two arrays of a different length, the data that gets written into contract is likely not what the caller intended. For example, if _indexes has more elements than _beneficiaires, then there will be emptied out beneficiaries added for the later _indices.

**Recommendations to fix**
Add a check at the top of the function to ensure `_indexes.length == _beneficiaries.length`

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 8] Emit an event when a new automator is set

**Where**
In Trustee.sol on [line 227](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L227)

**Impact**
Monitoring systems can not easily be notified of a change of automator

**Description**
It is best practice to emit events for any activity of interest that happens on a contract. This simplifies the monitoring by any external system. In this case, an event should be emitted for when a new automator is set.

**Recommendations to fix**
Create a new event, eg `ChangeAutomator`, and emit this event within `setAutomator`

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 9] Check that _beneficiaryIndex is a valid index

**Where**
In Trustee.sol on [line 241](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L241)

**Impact**
Contract needlessly continues to process an empty index while consuming transaction fees

**Description**
Inputs should always be validated, and in this case the `_beneficiaryIndex` should be verified to be within a valid index of the `msg.sender`'s list of beneficiaries.

**Recommendations to fix**
Add a require check at the top of the function to ensure the _beneficiaryIndex is <= trustData[msg.sender].beneficiaryCount

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 10] The new deadline should be calculated on top of the current deadline (trust.deadline), not the current block.timestamp.

**Where**
In Trustee.sol on [line 264](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L264)

**Impact**
According to the comments, `paySubscription` should increase the timer. However, it's current implementation ignores the current timer, and just sets the timer off of the current block.timestamp.

**Description**
The code implements different logic than the comment indicates. If the intent is to extend the timer, then the period should be added to the current deadline.

**Recommendations to fix**
Update the deadline to be `trustData[msg.sender].deadline + periodInSecs(uint8(trust.period))`

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 11] Follow best coding practices by putting internal functions at the end

**Where**
In Trustee.sol on [line 274](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L274)

**Impact**
Decreases readability by forcing the user to move up and down throughout the codebase to explore functions with different visibilities

**Description**
When reviewing a contract, it is helpful to follow convention with the layout of the contract. This includes putting public and external functions ahead of private and internal functions. Currently, the Trustee contract mixes these visibility types throughout.

**Recommendations to fix**
Move internal functions below all public and external functions

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 12] Be consistent in variable naming

**Where**
In Trustee.sol on [line 274](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L274)

**Impact**
Decreases readability by forcing the user to check in each function if a variable they are looking at was a passed in variable or not

**Description**
Some functions parameters are pre-fixed with an underscore, and some are not. Being consistent helps in code legibility.

**Recommendations to fix**
Decide on an approach, such as always pre-fixing function parameters with an underscore, and apply that throughout the code.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 13] Increment subscriptionCount after we set subscriptionData so that we maintain a zero-indexed array.

**Where**
In Trustee.sol on [line 275](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L275)

**Impact**
This breaks convention of having zero-indexed based arrays, and will cause confusion for anyone trying to read the data within the contract.

**Description**
`++subscriptionCount` increments the counter before we use it in the subsequent line. Instead, its current value should be used, and then it should be incremented.

**Recommendations to fix**
Use: subscriptionData[subscriptionCount++] = Subscription(owner, _period, _amount);

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 14] Documentation or comments should state if parameter is inclusive or not

**Where**
In Trustee.sol on [line 282](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L282)

**Impact**
Unclear for developers and auditors what expected behavior is

**Description**
As this is an external call, it should clearly indicate the expected behavior of the parameters.

**Recommendations to fix**
Add a comment to `getSubscriptions` indicating if the `end` index is to be included in the returned list of subscrpitions

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 15] Potential underflow error because of a missing check

**Where**
In Trustee.sol on [line 282](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L282)

**Impact**
Underflow error when start > end

**Description**
Because there is no check that end > start, if a start value is passed in that is greater than end, it results in an "Arithmetic over/underflow" error.

**Recommendations to fix**
Add a `require` that `end > start`

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

---

**Issue category**
Informational

**Issue title**
[INFORMATIONAL 16] `value` field is overloaded in Beneficiary struct

**Where**
In Trustee.sol on [line 29](
https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/main/Trustee.sol#L29)

**Impact**
Makes the code difficult to understand for someone reading it for the first time

**Description**
The use of the `value` field is overloaded for nft and erc20, and it is confusing to the reader. For an erc20 beneficiary, this seems to be a percentage of the overall, although that is not clearly indicated. 

**Recommendations to fix**
Consider creating another uint8 element in the struct called 'percentage', and slot it right after isNft so it gets included in the same storage slot. and rename this 'value' to nftTokenId. To enhance the storage saving, you can also move 'credited' to the top of the struct so it is included in the same storage slot as isNft and percentage

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here
