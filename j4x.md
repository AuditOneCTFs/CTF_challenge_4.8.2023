# High Issues

**Issue category**
High

**Issue title**
[H1] - Trusts will never be dissolved

**Where**
[Line 145](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L145)

**Impact**
Users will never be able to claim the tokens/NFTs they should receive as beneficiaries.

**Description**
In the createTrust() function the deadline is calculated by multiplying the current timestamp with the seconds for the period provided. For the smallest period, this would be 120 * timestamp. For this smallest period, the deadline would already be ~6000 years in the future. For even bigger periods it would be even further in the future.

Additional info:
Due to the bug in periodInSecs(), if a period > 10 would be provided, the deadline would be 0 and always fulfilled.

**Recommendations to fix**
Change to an addition instead of multiplication of the timestamp and the period in seconds.

```solidity
uint256 _deadline = block.timestamp + periodInSecs(_period);
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
High

**Issue title**
[H2] - Claim possible before the actual deadline.

**Where**
[Line 89](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L89)

**Impact**
Trusts can be claimed up to 15 seconds before their deadline (and possible extension)

**Description**
The contract uses block.timestamp to verify if the deadline of trust has already passed and beneficiaries can redeem their shares. A malicious miner could spoof a timestamp (by up to 15 seconds) so that a trust becomes claimable before it reached maturity. This could become an issue if users for example automatically renew their subscription a few seconds before the end. In this case, although they would validly renew their subscription, the beneficiary could already claim their part of the trust. A malicious actor could also, using this vulnerability, forcibly liquidate a full trust by forging the timestamp and calling to the bulkTransfers() function

**Recommendations to fix**
Method 1:
Only allow users to renew their subscription up to the deadline - 15 seconds or after the deadline (used for example if their beneficiaries haven't claimed and they want to renew the trust).

Method 2:
Rely on block.number instead of block.timestamp.

**Additional context**
https://cryptomarketpool.com/block-timestamp-manipulation-attack/

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
High

**Issue title**
[H3] - A malicious beneficiary can block the bulkTransfers() function or burn unnecessary gas of the caller

**Where**
[Line 232](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L232)

**Impact**

- unnecessary high gas cost
- blockage of the bulkTransfers() function for the whole trust

**Description**

If the bulkTransfers() function gets called, as a result, the transferHelper() function gets called for each beneficiary of the trust (ignoring the vulnerability of the missing increase of the beneficiaryCount variable, mentioned later). The transferHelper() function, in the case of the beneficiary.isNFT being true, uses IERC721(beneficiary.contractAddress).safeTransferFrom to transfer the NFT. The issue here is that this results in an external call to the onERC721Received() function of the receiver. As this function is externally controlled, a malicious actor could burn vast amounts of gas to either waste gas, or block the function bulkTansfer().

**Recommendations to fix**
To fix this issue the contract there are 2 possibilities:

1. Downgrade
The first mitigation would be to downgrade the call to a normal transferFrom(), which would result in the issue of NFTs possibly getting lost.

2. Adapting safeTransferFrom()
The second way to solve this would be to implement the safeTransferFrom() function yourself, but only add the gas needed for the standard ERC721Receiver() functionality and not more. This would result in the issue that if a beneficiary has implemented a custom onERC721Received() function, he would not be able to receive a NFT.


**Additional context**


**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
High

**Issue title**
[H4] - Automator can block subscriptions, subscription extensions or burn gas from users.

**Where**
[Line 67](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L67)

**Impact**
- Bad: Users spend unnecessary Gas on their transactions
- Worse: All deadlines can't be extended
- Even Worse: No new Trusts can be created
  
**Description**
The contract includes a modifier called transfer(). This modifier is used to send 1/2 of the msg.value to the address automator. This results in an external call to the receive function of the automator address. As this function is controlled by the Automator, not the owner of the contract or the user, it could be used to either just waste a lot of gas for each user, or to revert or burn all of the gas to make users unable to create new trusts or extend their subscriptions. This could also be used to force users to liquidate their trust, in case of the Automator just blocking all calls to paySubscription() until the deadline runs out, and then call to bulkTransfers() with the user's name. Users would be unable to prevent this from happening.

**Recommendations to fix**
There are 2 ways to address this.

1. Remove Automator

The easiest way would be to remove the automator role. It has no benefit to the contract's functionality.

2. Change automator reimbursement

Instead of reimbursing the automator at every created Trust, there could be a value for the automator's stake of the funds inside the contract. This gets increased by 1/2 of msg.value at every call with the transfer() modifier. Additionally, a function that allows the automator to withdraw would need to be added. The value that the owner can withdraw() using withdraw would need to be decreased by the automator's stake.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
High

**Issue title**
[H5] - Creators don't have to commit to the trust they create

**Where**
[Line 141](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L141)

**Impact**
The owner can revoke his allowances after creating a trust and no beneficiary will be able to claim the funds.
  
**Description**
As the contract is not holding any of the tokens / NFTs a fund creator doesn't commit to paying anything after the deadline. The creator just issues an allowance to the Trustee contract. This results in the issue that even when a fund was created, the creator can at any time just revoke or change the allowances and make all (or explicit ones) of the funds impossible to redeem.

**Recommendations to fix**
To fix this issue a change in the logic of the contract would be needed. This would require the owner to commit to the fund by transferring the funds to Trustee.sol. This way the owner couldn't revoke the fund without any interaction with Trustee. If the intention was to allow a owner to even after creation change the amount of tokens this could be added in a function(). Additionally, the deleteTrust function should refund the owner with all funds and also emit an event so beneficiaries know that the fund was dissolved.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
High

**Issue title**
[H6] - Allowance can be changed between payouts

**Where**
[Line 294](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L294)

**Impact**
Incorrect payouts 

**Description**
The creator's allowance to the contract is only checked at the first call to getEntitlementOnDeath(). The creator can change this allowance later or increase/decrease his balance of the token. The function would still calculate based on the values from the first call. This can result in incorrect transfers

**Recommendations to fix**
Do the check of the creator's allownace/balance of the token at each call to getEntitlementOnDeath(). 

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
High

**Issue title**
[H7] - Beneficiaries are not deleted

**Where**
[Line 159](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L159)

**Impact**
Users can unrightfully claim funds from a trust
  
**Description**
When a trust gets deleted, the beneficiaryData that is mapped to the address of the creator stays. This results in a case where users from an old deleted fund, can claim value from a new fund.

An example of this would look like this:
1. Alice creates a fund with two beneficiaries
2. _beneficiaries[0] is Bob who is allowed to claim 1 NFT
3. _beneficiaries[1] is Eve who is allowed to claim 100% of Token1
4. Alice deletes the trust before its deadline
5. Alice generates a new Fund with only one beneficiary called Carl, that will receive the NFT
6. beneficiaryData looks like this now:
beneficiaryData[0] = [Carl,...]
beneficiaryData[0] = [Eve,...]
1. The deadline runs out and Eve is (using the new trust) still able to claim 100% of Token1

**Recommendations to fix**
This vulnerability is pretty easy to fix as you just need to add the removal of beneficiaryData[msg.sender] to deleteTrust()

```solidity
function deleteTrust() public returns (Trust memory) {
    delete trustData[msg.sender];
    delete beneficiaryData[msg.sender];
    return trustData[msg.sender];
}
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
High

**Issue title**
[H8] - Trust gets blocked after bulkTransfer()

**Where**
[Line 233](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L233)

**Impact**
Users don't receive the intended funds
  
**Description**
After bulkTransfer() was run, the trusts .active variable gets set to false, although users might not have received their funds/NFTs. This could either be a result of the missing increase of beneficiaryCount which would lead to newly added beneficiaries never being compensated. It could also be the case that one of the beneficiaries has an incorrect implementation to receive ERC721 NFTs and has to fix this implementation to be able to receive the NFT.

**Recommendations to fix**
For the NFT use case, return false in transferHelper() if the transfer fails. Only if all calls to transferHelper() returned true, set active to false. The case of the new beneficiaries not being able to redeem their funds will be fixed when the beneficiaryCount variable is incremented correctly.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here
------------------------------------------------------------------------------------------------------------------------------------------------

# Medium Issues

**Issue category**
Medium

**Issue title**
[M1] - pricePerBeneficiary is never collected

**Where**
[Line 141](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L141)

**Impact**
No fee is collected per Beneficiary, resulting in a loss to the owner.

**Description**
The contract includes a variable called pricePerBeneficiary which probably should be paid for by the users, per beneficiary they add to their Trust. The issue is that this variable is never used in any way and so users don't have to pay per beneficiary.

**Recommendations to fix**
There are 2 ways how this can be fixed.

- Remove the pricePerBeneficiary

If the cost per beneficiary is not wanted, the variable as well as the related function should be removed to save gas.

- Use the pricePerBeneficiary

If the use of pricePerBeneficiary is intended but was forgotten during development, the fee needs to be collected in the functions createTrust() and addToMyTrustBeneficiaries()

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Medium

**Issue title**
[M2] - The price for subscription is not collected when trust is created

**Where**
[Line 141](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L141)

**Impact**
No fee is collected at the creation of each trust, resulting in a loss to the owner.

**Description**
The contract includes a variable called subscriptionPrice which should be paid for by the users, to sustain their trust. This fee is invoked once a subscription gets extended by calling paySubscription() but not when a contract is created.

**Recommendations to fix**
This issue can be solved by adding the subscriptionCheck() modifier to the head of the createTrust() function. This can be done like this:

```solidity
function createTrust(Beneficiary[] calldata _beneficiaries, string calldata _description, string calldata _title, uint8 _period) payable external subscriptionCheck transfer {
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Medium

**Issue title**
[M3] - Missing allowance checks

**Where**
[Line 141](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L141)

**Impact**
Funds that were intended for the fund can get stuck if access to the creator's private keys is lost. Additionally, beneficiaries might not get their intended share.

**Description**
When generating Beneficiary structs for a token, the beneficiary.value symbolizes the percentage of the whole allowance of that token that will go to the beneficiary. The issue is that it's not checked if the full allowance (100%) is distributed between the beneficiaries. It could also be way less or way more. In the case of it being way less, tokens would get stuck if they can not be transferred anymore and the allowance to Trustee.sol was the only allowance issued. If the summed percentage would be more than 100%, the tokens would go to the beneficiaries that claim their parts the earliest and the others would get no tokens.

**Recommendations to fix**

This is complex to fix as there might be multiple tokens involved in the trust. The optimal way would be to add a mapping, of contract_address => percentage_issued, to the Trust struct and increase the value of the contract address for each beneficiary.value with that contract address. In the end, the function should check if for each token the percentage_issued == 100, and otherwise revert.

```solidity
struct Trust{
    uint256 deadline;
    uint256 amount;
    string title;
    string description;
    bool active;
    uint256 beneficiaryCount;
    Period period;
    mapping(address contract_address => uint8 percentage_issued) percentages; 
}
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
[M4] - Medium

**Issue title**
Subscription price is not based on the period

**Where**
[Line 58](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L58)

**Impact**
Users are incentivized to pick a longer duration instead of prolonging their subscription, which results in lost earnings for the owner.

**Description**
Each trust has a period, associated with it. At the start, this period is used to calculate the deadline, by adding it to the current timestamp. In the current implementation, this creation step doesn't need any payment. in my understanding of the business logic, it might be intended that this is also already charged in the creation. If the deadline runs out a user can extend it by calling the paySubscription() function. Nevertheless, the issue is that all chosen periods cost the same amount. Imagine this case:
A user wants to have a trust with a duration of one hour, after which it can be redeemed. The user can either pick the 2min period and renew it 30x costing him 0.003 ether or he can just pick the period as 1 hour and not pay anything (only once in case of a fee deduction in the creation).

**Recommendations to fix**
This could easily be fixed by adding a mapping of periods to subscriptionFees. So that each period has an associated fee and users are not incentivized to pick high periods to increase their trusts deadline.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Medium

**Issue title**
[M5] - Wrong check in subscriptionCheck() function

**Where**
[Line 82](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L82)

**Impact**
Users might overpay for their subscription

**Description**
The require() statement in the subscriptionCheck() modifier check for the msg.value being bigger than the subscriptionPrice variable. According to the error message, this modifier is intended to check for the msg.value being the same as subscriptionPrice. This require() statement would still pass if a user sent more than their subscriptionPrice, which could happen by error, and would result in them overpaying.

**Recommendations to fix**
Adapt the require statement to check for the msg.value being equal to subscriptionPrice:

```solidity
require(msg.value = subscriptionPrice, "Amount should be equal to subscription Price");
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Medium

**Issue title**
[M6] - beneficiaryCount variable is not updated

**Where**
[Line 178](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L178)

**Impact**

- return of getMyTrustBeneficiaries() function is incorrect
- bulkTransfers() function does not do all necessary transfers

**Description**
A user can call the function addToMyTrustBeneficiaries() to add new beneficiaries to his trust. Unfortunately, this function doesn't update the beneficiaryCount variable of his trust, by adding the number of new beneficiaries that were added. This results in other functions executing incorrectly, as they rely on the value to loop over the beneficiaries.

**Recommendations to fix**
Increase beneficiaryCount in the addToMyTrustBeneficiaries() function. 

```solidity
function addToMyTrustBeneficiaries (Beneficiary [] calldata _beneficiaries) public  {
    uint256 count = trustData[msg.sender].beneficiaryCount;
    for (uint256 i = 0; i < _beneficiaries.length; i++) {
        beneficiaryData[msg.sender][count + i] = _beneficiaries[i];
    }
    trustData[msg.sender].beneficiaryCount += _beneficiaries.length;
}
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
[M7] - Medium

**Issue title**
Contract might not work with non-ERC20 tokens or non-ERC721 NFTs.

**Where**
[Line 245](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L245)

**Impact**
Tokens / NFTs might get stuck forever
  
**Description**
The contract relies on the IERC20 and IERC721 interfaces to interact with the tokens / NFTs and send them to the beneficiaries. The comments/documentation never mention that the contract only works with tokens/NFTs following these interfaces, so users might set up trusts with contracts based on other frameworks. This would then result in the Trustee contract not being able to distribute the funds.

**Recommendations to fix**
Communicate, through Documentation, Frontend, and comments that the contract is only able to handle ERC20/ERC721.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Medium

**Issue title**
[M8] - Missing Input value check for Tokens

**Where**
[Line 141](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L141)
[Line 170](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L170)
[Line 178](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L178)

**Impact**
The beneficiary will not be able to claim tokens.
  
**Description**
In the transfer functions which are used to distribute the funds at the end of the deadline the beneficiary value is used as a percentage of the allowance of the tokens that the beneficiary will receive if the isNFT parameter is set to false. If the value is set to higher than 100, the beneficiary is marked as credited but doesn't receive anything. As there is no mention in the code that describes that this value is used as a percentage, the creator of a trust might mistake it for the number of tokens. In that case, the allowance would get stuck forever.

**Recommendations to fix**
Add a check that verifies that the value is <= 100 for beneficiary objects where isNFT is set to false. Add this to all 3 functions where beneficiaries get added/updated.

```solidity
if(!_beneficiaries[i].isNft)
    require(_beneficiaries[i].value <= 100, "Percentage of allowance can't be more than 100");
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Medium

**Issue title**
[M9] - Missing Input value check for NFTs

**Where**
[Line 141](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L141)
[Line 170](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L170)
[Line 178](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L178)

**Impact**
The beneficiary will not be able to claim the NFT.
  
**Description**
In the transfer functions which are used to distribute the funds at the end of the deadline the beneficiary value is used as the id of the NFT. This doesn't check if the creator is the owner of the NFT.

**Recommendations to fix**
Add a require() statement that checks if the creator of the trust is the owner of the NFT to all 3 functions.

```solidity
if(_beneficiaries[i].isNft)
    require(IERC721(_beneficiaries[i].contractAddress).ownerOf(_beneficiaries[i].value) == msg.sender, "You can't add a NFT you don't own to the trust.");
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Medium

**Issue title**
[M10] - getEntitlementOnDeath leaves dust

**Where**
[Line 292](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L292)

**Impact**
Full funds are not always paid out to beneficiaries

**Description**
As the function getEntitlementOnDeath() does the calculation of the tokens that should be paid out to beneficiaries using percentages the calculation might result in dust left in the allowance which can't be retrieved by anyone due to solidity rounding down on divisions.

Example:
I tested a quick example to showcase this. A trust has an allowance of 9 tokens and there are 3 beneficiaries with percentages of 30(User1), 30(User2), and 40(User3) for those tokens. Using the calculation, User1 and User2 would receive 2 tokens each, user 3 would receive 3 tokens. This would result in only 7 out of 9 tokens being distributed and the rest being stuck. This would be a loss of 22.3% of tokens.

This Error decreases as the amount of tokens increases, but still results in minor losses.

**Recommendations to fix**
As the percentage model for tokens leads to minor losses for customers and higher complexity of the code, I would recommend changing the code so that instead of using percentages, the absolute amount of tokens is used.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

# Low Issues


**Issue category**
Low

**Issue title**
[L1] - Missing zero address check for beneficiaries

**Where**
[Line 141](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L141)
[Line 170](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L170)
[Line 178](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L178)

**Impact**
Tokens or NFTs inside the trust might be burned.

**Description**
When a beneficiary is initialized it has a variable named beneficiaryAddress. This is the person, wallet, or contract that should receive the tokens or NFT when the trust passes its deadline. Due to no checks for zero addresses, the beneficiaryAddress might be zero. In case of the trust's deadline passes and someone calls one of the transfer functions, the tokens/NFT will be burned.

**Recommendations to fix**
Add a check for zero addresses in the functions that add/update beneficiaries. Such a check might look like this.

```solidity
require(_beneficiaries[i].beneficiaryAddress != 0, "Zero address can't be the beneficiary.");
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Low

**Issue title**
[L2] - Missing zero address & codelength check for contract addresses

**Where**
[Line 141](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L141)
[Line 170](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L170)
[Line 178](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L178)

**Impact**
Some beneficiary tokens/NFTs can never be redeemed

**Description**
When a beneficiary is initialized it has a variable named contractAddress. This is the NFT or token contract in which the tokens should be distributed. Trustee.sol never check if these addresses are either zero or if they don't contain any bytecode(are EOA). If this is the case, any call to them will revert.

**Recommendations to fix**
Add a check for zero address as well as for bytecode in the functions that add/update beneficiaries. Such a check might look like this.

```solidity
address contract_addr = _beneficiaries[i].contractAddress
require(contract_addr != 0, "Zero address can't be the contract.");

uint32 size;
assembly {
    size := extcodesize(contract_addr)
}
require((size > 0), "Contract Address has to be a contract");
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Low

**Issue title**
[L3] - The wrong value returned in trustStatus()

**Where**
[Line 128](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L128)

**Impact**
Users receive incorrect deadline value

**Description**
the function trustStatus() can be used by users to check if a trust has already passed its deadline and can be redeemed. Due to an off-by-one error, in the case of the block.timestamp being equal to the trust.deadline this function would return true. This is an issue due a trust redeemability being restricted by the creditBeneficiary() modifier. This only passes if block.timestamp > trust.deadline. So in the case of both being equal a user might call trustStatus() to verify if he can already redeem parts of a trust. This would return true but the redeem would not pass. This could be an issue if both are done in a single transaction.

**Recommendations to fix**
Change the condition so that it works the same way as in the creditBeneficiary() modifier. 

```solidity
function trustStatus(address _willOwner) public view returns(bool, bool, uint256){
    bool deadline;
    Trust memory trust = trustData[_willOwner];
    
    if(block.timestamp > trust.deadline){
        deadline = true;
    }else{
        deadline = false;
    }
    return (deadline, trust.active, trust.beneficiaryCount);
}
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Low

**Issue title**
[L4] - The periodInSecs() function yields an incorrect value

**Where**
[Line 101](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L101)

**Impact**
Users don't have to pay any subscription fee, periodInSecs() returns an incorrect value

**Description**
The periodsInSecs() function checks all values from 0-10 and returns a corresponding amount of seconds. If a value greater than 10 (in the boundaries of uint8) is supplied, the function returns 0 instead of reverting(as this would be an invalid input).

**Recommendations to fix**
Add a require() statement that checks if the _period is in the intended boundaries.

```solidity
require(_period <= 10, "Invalid Input Period.")
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Low

**Issue title**
[L5] - deleteTrust() always returns zero

**Where**
[Line 159](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L159)

**Impact**
Users don't receive the data of the trust they deleted as a return value

**Description**
In the deleteTrust() function a user can delete his entry in the trustData mapping. After this, the function should return the data of the trust that was deleted. This doesn't work because the mapping entry, that was deleted before is returned.

**Recommendations to fix**
To be able to return the correct Trust object, the object needs to be cached before deleting like this:

```solidity
function deleteTrust() public returns (Trust memory) {
    Trust cachedTrust = trustData[msg.sender];
    delete trustData[msg.sender];
    return cachedTrust;
}
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

# Gas Optimization Issues

**Issue category**
Gas Optimization

**Issue title**
[L6] - The periodInSecs() function can be replaced by a mapping.

**Where**
[Line 101](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L101)

**Impact**
Gas waste

**Description**
The function periodInSecs() is used to map uint8 values to uint256 values. As this is done using a concatenation of multiple if/else if-blocks a lot of gas waste happens.

**Recommendations to fix**
This could easily be fixed by using a mapping (uint8 => uint256) periodInSecs. You would only need to initialize this mapping once and then just call periodInSecs[period] to get the uint256 value.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Gas Optimization

**Issue title**
[L7] - Trust variable amount can be removed

**Where**
[Line 38](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L38)

**Impact**
Gas waste

**Description**
The trust struct includes the variable amount. This variable is not used for anything in the contract logic, and a fixed contract will always resemble the subscription fee. This added variable increases the struct size and so wastes storage space and gas.

**Recommendations to fix**
Remove the variable

**Additional context**


**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Gas Optimization

**Issue title**
[G1] - Functions can be marked as external.

**Where**
[Line 128](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L128)
[Line 159](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L159)
[Line 170](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L170)
[Line 178](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L178)
[Line 185](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L185)
[Line 203](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L203)
[Line 232](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L232)
[Line 241](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L241)
[Line 304](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L304)

**Impact**
Gas waste

**Description**
The functions are never called inside the contract. So they can be marked as external.

**Recommendations to fix**
Change the visibility of the functions to external.

**Additional context**
[Public vs. External](https://gus-tavo-guim.medium.com/public-vs-external-functions-in-solidity-b46bcf0ba3ac)

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Gas Optimization

**Issue title**
[G2] - Structs are not optimally packed

**Where**
[Line 27](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L304)
[Line 36](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L36)

**Impact**
Gas waste

**Description**
The structs used are not optimally packed to reduce gas usage. 

**Recommendations to fix**
The structs should be packed more efficiently. This has to be done for each one on its own. In the following, I will show a more tightly packed structure and show how many storage slots can be saved.

Beneficiary:
```solidity
    struct Beneficiary {
        //Slot 1
        address beneficiaryAddress;
        bool isNft;
        //Slot 2
        address contractAddress;
        bool credited;
        //Slot 3
        uint256 value;
        //Slot 4
        string description;
    }
```

Reduction from 6 to 4 slots (33% storage cost saved)

Trust:
```solidity
struct Trust{
    //Slot 1
    uint256 deadline;
    //Slot 2
    uint256 amount;
    //Slot 3
    string title;
    //Slot 4
    string description;
    //Slot 5
    uint256 beneficiaryCount;
    //Slot 6
    Period period; //is only uint8 as it has less than 256 members
    bool active;
}
```

Reduction from 7 to 6 slots (14% storage cost saved)

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Gas Optimization

**Issue title**
[G3] - Inefficient increment in for loops

**Where**
[Line 147](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L147)
[Line 172](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L172)
[Line 180](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L180)
[Line 188](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L188)
[Line 234](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L234)
[Line 286](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L286)

**Impact**
Gas waste

**Description**
The increment is done using a new solidity compiler so over/underflow checks are done at each increment.

**Recommendations to fix**
The incrementation of the variable in the for loops can be done in an unchecked block as it will never overflow. For example, the for loop in Line 173 would then look like this.

```solidity
for (uint256 i = 0; i < _indexes.length;) {
    if (_indexes[i] > count) continue;
    beneficiaryData[msg.sender][_indexes[i]] = _beneficiaries[i];
    unchecked {
        i++;
    }
}
```

**Additional context**
[Loop Optimization](https://hackmd.io/@totomanov/gas-optimization-loops)

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Gas Optimization

**Issue title**
[G4] - Inefficient caching in for loop

**Where**
[Line 172](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L172)
[Line 180](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L180)

**Impact**
Gas waste

**Description**
The call to .length is not cached but done at each iteration, which wastes lots of gas.

**Recommendations to fix**
The value of variable.length should be cached before. For the loop in [Line 172](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L172) this would look like this:

```solidity
uint256 indexesLength = _indexes.length
for (uint256 i = 0; i < indexesLength; i++) {
    if (_indexes[i] > count) continue;
    beneficiaryData[msg.sender][_indexes[i]] = _beneficiaries[i];
}
```

**Additional context**
[Loop Optimization](https://hackmd.io/@totomanov/gas-optimization-loops)

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Gas Optimization

**Issue title**
[G5] - Unnecessary function getApprovedTokens

**Where**
[Line 207](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L207)

**Impact**
Gas waste

**Description**
There is a function in the contract that returns an owner's token allowance to the Trustee contract. This function only does a call to allowance() function of the token, which a user could also do himself.

**Recommendations to fix**
Remove the unnecessary function.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Gas Optimization

**Issue title**
[G6] - The variable subscriptionPrice is unnecessarily updated

**Where**
[Line 216](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L216)

**Impact**
Gas waste

**Description**
In the function setSubcriptionPrice(), which is used to set a new value as the subscription price, the price is once set to 0.0001 ether before being updated to the parameter passed to the function. This results in 2 storage writes instead of one, which wastes gas.

**Recommendations to fix**
Only update the variable to the parameter that was passed to the function.

```solidity
function setSubcriptionPrice (uint256 _price) external onlyOwner {
    subscriptionPrice = _price;
}
```

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Gas Optimization

**Issue title**
[G7] - The variable pricePerBeneficiary is unnecessarily updated

**Where**
[Line 221](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L221)

**Impact**
Gas waste

**Description**
In the function setPricePerBeneficiary(), which is used to set a new value as the beneficiary price, the price is once set to 0.0001 ether before being updated to the parameter passed to the function. This results in 2 storage writes instead of one, which wastes gas.

**Recommendations to fix**
Only update the variable to the parameter that was passed to the function.

```solidity
function setPricePerBeneficiary (uint256 _price) external onlyOwner {
    pricePerBeneficiary = _price;
}
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here


------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Gas Optimization

**Issue title**
[G8] - Unused variable accumulator

**Where**
[Line 64](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L64)

**Impact**
Gas waste

**Description**
The contract includes the variable accumulator, which is never used.

**Recommendations to fix**
Remove the variable

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Gas Optimization

**Issue title**
[G9] - Unnecessary call to getTokenStatus()

**Where**
[Line 294](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L294)

**Impact**
Gas waste

**Description**
The function getEntitlementOnDeath() includes a call to the getTokenStatus() function, which yields the values allowance and balance. These are only used if initialBalance == 0. So the call is unnecessary gas waste in all other cases.

**Recommendations to fix**
Move the call so that it is only done when initialBalance == 0:

```solidity
function getEntitlementOnDeath (address _willOwner, Beneficiary memory _beneficiary) internal returns(uint256) {

    uint256 initialBalance = initialTokenBalance[_willOwner][_beneficiary.contractAddress];
    uint256 value = _beneficiary.value;

    if (initialBalance == 0) {
        (uint256 allowance, uint256 balance) = getTokenStatus(_beneficiary.contractAddress, _willOwner);
        uint256 amount = allowance > balance ? balance : allowance;
        initialTokenBalance[_willOwner][_beneficiary.contractAddress] = amount;
        return ((amount * value) / 100) > amount ? 0 : ((amount * value) / 100);
    }

    return ((value * initialBalance) / 100) > initialBalance ? 0 : ((value * initialBalance) / 100);
}
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

# Informational Issues

**Issue category**
Informational

**Issue title**
[I1] - Visibility of variables not declared

**Where**
[Line 63](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L63)
[Line 64](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L64)

**Impact**
Harder readability of the code for following developers/auditors.

**Description**
The 2 variables automator and accumulator are not assigned visibility (private, public, internal, external). The solidity compiler will automatically declare the variables as internal.

**Recommendations to fix**
If the variables are intended to be declared as internal, directly declare them this way like this:

```solidity
address payable internal automator;
uint256 internal accumulator;
```

If different visibility is intended, assign the intended visibility.

**Additional context**
[State Variable / Function Visibility](https://www.geeksforgeeks.org/function-visibility-specifier-in-solidity/)

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I2] - Variable can be delared as uint256

**Where**
[Line 306](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L306)

**Impact**
The source code is harder to understand.

**Description**
The variable amount is declared as uint. This automatically maps to uint256, but this might not be clear to someone working on the code later.

**Recommendations to fix**
To make the code easier to understand declare both variables as uint256.
```solidity
uint256 amount = address(this).balance;
```

**Additional context**
https://www.alchemy.com/overviews/solidity-uint#:~:text=Uint%20Data%20Sizes&text=An%20unsigned%20integer%20value%20data,%2C%20uint64%2C%20uint128%20and%20uint256.

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I3] - Private/Internal functions/variables are not named according to the Solidity Style Guide

**Where**
[Line 53](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L53)
[Line 101](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L101)
[Line 245](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L245)
[Line 274](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L274)
[Line 292](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L292)

**Impact**
Bad code readability

**Description**
The private/internal functions/variables should have a name starting with an "_" to make it easy to see that they are not user accessible.

**Recommendations to fix**
Rename functions/variables according to the solidity style guide.

**Additional context**
[Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I4] - Functions & Variables are not ordered according to the solidity style guide.

**Where**
Full contract

**Impact**
Bad code readability

**Description**
The functions and variables are mixed around and there is no order. According to The solidity style guide here, they should be in the order:

- constructor
- receive function (if exists)
- fallback function (if exists)
- external
- public
- internal
- private

**Recommendations to fix**
Reorder the functions according to the solidity style guide.

**Additional context**
[Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I5] - Modifiers & Events are inverted in order

**Where**

**Impact**
Bad code readability

**Description**
The modifiers and events are in the wrong order. According to the solidity style guide, the start of a contract should be in the order:
1. Type declarations
2. State variables
3. Events
4. Errors
5. Modifiers
6. Functions

**Recommendations to fix**
Change the order of modifiers and events

**Additional context**
[Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I6] - Non-Fixed Solidity version

**Where**
[Line 2](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L2)

**Impact**
Possible compilation with an old version of solidity.

**Description**
The pragma is not fixed to a certain version but is set to a version newer than 0.8.0.

**Recommendations to fix**
Set the version to a fixed version of the compiler. This can be achieved by changing the pragma to:

```solidity
pragma solidity 0.8.19;
```

**Additional context**
https://www.oreilly.com/library/view/mastering-blockchain-programming/9781839218262/d1250994-b952-4d5e-9cde-1b852c18b55f.xhtml

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I7] - Missing Documentation

**Where**


**Impact**
The code is hard to understand.

**Description**
The code contains only a few comments and no additional documentation on which behavior is intended or needed.

**Recommendations to fix**
Add Comments to the code as well as provide additional documentation on the intended behavior. The comments should follow the solidity natspec syntax.

**Additional context**
https://docs.soliditylang.org/en/develop/natspec-format.html

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I8] - transfer() modifier is badly named

**Where**
[Line 67](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L67)

**Impact**
The name collision could lead to confusion for other developers.

**Description**
The code includes a modifier which is named transfer(). Unfortunately, there also is a function in solidity called transfer() which is used to transfer value. This could lead to developers in the future mixing up.

**Recommendations to fix**
The easiest fix is to rename the modifier. A possible name could just be transferModifier().
**Additional context**
[Transfer function](https://solidity-by-example.org/sending-ether/)

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I9] - Missing emits in Trust-functions

**Where**

**Impact**
Harder monitoring of the contract.

**Description**
The functions updateMyTrustBeneficiaries(), addToMyTrustBeneficiaries(), deleteTrust() are missing events to emit when called. This makes it harder to track/monitor the contract, once deployed.

**Recommendations to fix**
Add custom events for each of these functions and emit them once the function is finished.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I10] - Missing emits in Admin-functions

**Where**
[Line 216](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L216)
[Line 221](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L221)
[Line 226](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L226)

**Impact**
Harder monitoring of the contract.

**Description**
The admin functions setSubcriptionPrice(), setPricePerBeneficiary(), setAutomator(), withdraw() are missing events to emit when called. This makes it harder to track/monitor the contract, once deployed. This is especially important to customers as they wouldn't be able to directly see a change in the subscription price if they would only check the events.

**Recommendations to fix**
Add custom events for each of these functions and emit them once the function is finished.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I11] - Not explicitly set library version in imports.

**Where**
[Line 4-8](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L4)

**Impact**
Possible future vulns

**Description**
No explicit version is set for the contracts that are imported. 

**Recommendations to fix**
Set explicit Versions for each import.

```solidity
import "@openzeppelin/contracts@4.9.3/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts@4.9.3/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.9.3/access/Ownable.sol";
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I12] - No named imports

**Where**
[Line 4-8](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L4)

**Impact**
Unnecessary imports

**Description**
No distinct contracts are imported but the whole file for each contract.

**Recommendations to fix**
Add named imports like this:

```solidity
import {IERC721} from "@openzeppelin/contracts@4.9.3/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts@4.9.3/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts@4.9.3/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts@4.9.3/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts@4.9.3/access/Ownable.sol";
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I13] - Variable _owner is shadowed

**Where**
[Line 304](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L304)

**Impact**
Possible future vulnerabilities, Harder readability of code

**Description**
As the contract inherits from the Ownable.sol OpenZeppelin contract, it also inherits the _owner variable. In the function withdraw() it also declares a variable _owner, which it initializes to the original _owner by calling the owner() function. This leads to the shadowing of the original variable which is completely unnecessary.

**Recommendations to fix**
just use _owner directly in the function like this:

```solidity
function withdraw () public onlyOwner {
    uint amount = address(this).balance;
    (bool sent, ) = _owner.call{value: amount}("");
    require(sent, "Failed to withdraw funds!!");
}
```

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I14] - Bad struct name Beneficiary

**Where**
[Line 27](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L27)

**Impact**
Bad readability of Code

**Description**
The struct that is called beneficiary, is not used to track beneficiaries, but the goods/parts inside the trust. So there can be multiple Beneficiary structs pointing to one beneficiary. This leads to reduced intelligibility of the code.

**Recommendations to fix**
Rename the struct to something like Good.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

------------------------------------------------------------------------------------------------------------------------------------------------

**Issue category**
Informational

**Issue title**
[I15] - Automator Variable name, not a good fit

**Where**
[Line 64](https://github.com/AuditoneCodebase/CTF_challenge_4.8.2023/blob/5d60d3063af56dea7aa12f076a5858373a1069bc/Trustee.sol#L63)

**Impact**
Code harder to understand

**Description**
The contract includes a variable called automator. This address, if not 0, receives half of the subscription fees (and potential overpaid value) from customers that call a function with the transfer modifier.

**Recommendations to fix**
The address doesn't do any automation, so a better-fitting name or total removal of the address would be recommended.

**Additional context**

**Comments by AuditOne**
AuditOne team can comment here

