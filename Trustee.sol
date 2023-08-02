//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Trustee is ReentrancyGuard, Ownable {

    //cron period time
    enum Period {
        MINUTE_2,
        MINUTE_5,
        MINUTE_10,
        MINUTE_30,
        HOUR_1,
        DAY_1,
        WEEK_1,
        MONTH_1,
        MONTH_3,
        MONTH_6,
        YEAR_1
    }

    struct Beneficiary {
        bool isNft;
        uint256 value;
        string description;
        address beneficiaryAddress;
        address contractAddress;
        bool credited;
    }

    struct Trust{
        uint256 deadline;
        uint256 amount;
        string title;
        string description;
        bool active;
        uint256 beneficiaryCount;
        Period period;
    }

    struct Subscription {
        address subscriber;
        Period period;
        uint256 price;
    }

    mapping(address => Trust) public trustData;
    mapping(address => mapping(uint256 => Beneficiary)) private beneficiaryData;

    mapping(uint256 => Subscription) public subscriptionData;
    mapping(address => mapping(address => uint256)) public initialTokenBalance;

    uint256 public subscriptionPrice = 0.0001 ether;
    uint256 public pricePerBeneficiary = 0.0001 ether;

    uint256 public subscriptionCount = 0;

    address payable automator;
    uint256 accumulator;

    // modifiers section
    modifier transfer() {
        if(msg.value > 0){
            Trust memory trust = trustData[msg.sender];
            if(automator != address(0)) {
                uint256 automatorAmount = msg.value / 2;
                (bool sent, ) = payable(automator).call{value: automatorAmount}("");
                require(sent, "Failed to withdraw funds!!");
            }
            _;
        }else{
            revert("Insufficient funds to create trust");
        }
    }

    modifier subscriptionCheck {
        require(msg.value >= subscriptionPrice, "Amount should be equal to subscription Price");
        _;
    }

    modifier creditBeneficiary(address _willOwner) {
        Trust memory trust = trustData[_willOwner];
        require(trust.active);
        require(block.timestamp > trust.deadline, "Not past deadline");
        _;
    }

    //-end modifier section

    
    event CreateTrust(address indexed owner, string title, string description);
    event Subscriptions(address indexed owner, uint256 amount, Period period);
    event TransferToBeneficiary(address indexed owner, address indexed beneficiary, address indexed contractAddress, bool isNft, uint256 value);


    function periodInSecs(uint8 _period) private pure returns (uint256 _periodInSecs){
        
        if(_period == 0){
            return 2 minutes;
        } else if(_period == 1){
            return 5 minutes;
        } else if(_period == 2){
            return 10 minutes;
        } else if(_period == 3){
            return 30 minutes;
        } else if(_period == 4){
            return 1 hours;
        } else if(_period == 5){
            return 1 days;
         }else if(_period == 6){
            return 1 weeks;
        } else if(_period == 7){
            return 2419200;
        } else if(_period == 8){
            return 7257600;
        } else if(_period == 9){
            return 14515200;
        } else if(_period == 10){
            return 29030400;
        }
    }
    
    function trustStatus(address _willOwner) public view returns(bool, bool, uint256){
        bool deadline;
        Trust memory trust = trustData[_willOwner];
        if(block.timestamp >= trust.deadline){
            deadline = true;
        }else{
            deadline = false;
        }
        return (deadline, trust.active, trust.beneficiaryCount);
    }


    //at the expiration of the deadline, the funds will be released to the beneficiary's address.
    function createTrust(Beneficiary[] calldata _beneficiaries, string calldata _description, string calldata _title, uint8 _period) payable external transfer {
        require(!trustData[msg.sender].active, "Address can't have multiple active trusts");

        uint256 count = _beneficiaries.length;
        uint256 _deadline = block.timestamp * periodInSecs(_period);

        for (uint256 i = 0; i < count; i++) {
            beneficiaryData[msg.sender][i] = Beneficiary(_beneficiaries[i].isNft, _beneficiaries[i].value, _beneficiaries[i].description, _beneficiaries[i].beneficiaryAddress, _beneficiaries[i].contractAddress, false);
        }

        trustData[msg.sender] = Trust(_deadline, msg.value, _title, _description, true, count, Period(_period));
        
        subscribe(msg.sender, Period(_period), msg.value);

        emit CreateTrust(msg.sender, _title, _description);

    }

    function deleteTrust() public returns (Trust memory) {
        delete trustData[msg.sender];
        return trustData[msg.sender];
    }

    //get Trust Details
    function getMyTrust() external view returns(Trust memory) {
        return trustData[msg.sender];
    }

     // protect against indexes that are out of bound
    function updateMyTrustBeneficiaries (uint256[] calldata _indexes, Beneficiary [] calldata _beneficiaries) public {
        uint256 count = trustData[msg.sender].beneficiaryCount;
        for (uint256 i = 0; i < _indexes.length; i++) {
            if (_indexes[i] > count) continue;
            beneficiaryData[msg.sender][_indexes[i]] = _beneficiaries[i];
        }
    }

    function addToMyTrustBeneficiaries (Beneficiary [] calldata _beneficiaries) public  {
        uint256 count = trustData[msg.sender].beneficiaryCount;
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            beneficiaryData[msg.sender][count + i] = _beneficiaries[i];
        }
    }

    function getMyTrustBeneficiaries () public view returns(Beneficiary [] memory) {
        uint256 count = trustData[msg.sender].beneficiaryCount;
        Beneficiary[] memory beneficiaries = new Beneficiary[](count);
        for (uint256 i = 0; i < count; i++) {
            beneficiaries[i] = beneficiaryData[msg.sender][i];
        }
        return beneficiaries;
    }

    function isApproved (address _nftAddress, uint256 _tokenId) public view returns(bool) {
        if (IERC721(_nftAddress).getApproved(_tokenId) != address(this)) {
            return false;
        } else {
            return true;
        }
    }


    function getApprovedTokens(address tokenAddress, address owner) public view returns(uint256) {
        return IERC20(tokenAddress).allowance(owner, address(this));
    }

    function getTokenStatus(address tokenAddress, address owner) public view returns(uint256, uint256) {
        uint256 allowance = IERC20(tokenAddress).allowance(owner, address(this));
        uint256 balance = IERC20(tokenAddress).balanceOf(owner);
        return (allowance, balance);
    }



    // Admin Functions
    function setSubcriptionPrice (uint256 _price) external onlyOwner {
        subscriptionPrice = 0.0001 ether;
        subscriptionPrice = _price;
    }

    function setPricePerBeneficiary (uint256 _price) external onlyOwner {
        pricePerBeneficiary = 0.0001 ether;
        pricePerBeneficiary = _price;
    }

    function setAutomator (address payable _automator) external onlyOwner {
        automator = _automator;
    }
    //end admin fuctions


    function bulkTransfers (address _willOwner) public creditBeneficiary(_willOwner) nonReentrant {
        uint256 count = trustData[_willOwner].beneficiaryCount;
        for (uint256 i = 0; i < count; i++) {
            transferHelper(_willOwner, i);
        }
        trustData[_willOwner].active = false;
    }


    function singleTransfer (address _willOwner, uint256 _beneficiaryIndex) public creditBeneficiary(_willOwner) nonReentrant {
        transferHelper(_willOwner, _beneficiaryIndex);
    } 

    function transferHelper (address _willOwner, uint256 _beneficiaryIndex) internal creditBeneficiary(_willOwner) {
        Beneficiary memory beneficiary = beneficiaryData[_willOwner][_beneficiaryIndex];
        if (!beneficiary.credited) {
            if (beneficiary.isNft) {
                if(isApproved(beneficiary.contractAddress, beneficiary.value)) {
                    IERC721(beneficiary.contractAddress).safeTransferFrom(_willOwner, beneficiary.beneficiaryAddress, beneficiary.value);
                }
            } else {
                uint256 value = getEntitlementOnDeath(_willOwner, beneficiary);
                SafeERC20.safeTransferFrom(IERC20(beneficiary.contractAddress), _willOwner, beneficiary.beneficiaryAddress, value);
            }
            beneficiaryData[_willOwner][_beneficiaryIndex].credited = true;
        }

        emit TransferToBeneficiary(_willOwner, beneficiary.beneficiaryAddress, beneficiary.contractAddress, beneficiary.isNft, beneficiary.value);

    } 

    // This fuction should increase timer for the will
    function paySubscription () payable external transfer subscriptionCheck {
        Trust memory trust = trustData[msg.sender];
        
        uint256 _deadline = block.timestamp + periodInSecs(uint8(trust.period));

        trustData[msg.sender].deadline =_deadline; 
        
        subscribe(msg.sender, trust.period, msg.value);
    }

    function subscribe (address owner, Period _period, uint256 _amount) internal {
        ++subscriptionCount;
        subscriptionData[subscriptionCount] =  Subscription(owner, _period, _amount);
        emit Subscriptions(owner, _amount, _period);
    }


    //for tracking subscription
    function getSubscriptions (uint256 start, uint256 end) external view returns(Subscription[] memory) {
        uint256 count = end - start;
        Subscription[] memory subscription = new Subscription[](count);
        uint256 counter = 0;
        for (uint256 i = start; i < end; i++) {
            subscription[counter++] = subscriptionData[i];
        }
        return subscription;
    }

    function getEntitlementOnDeath (address _willOwner, Beneficiary memory _beneficiary) internal returns(uint256) {
        uint256 initialBalance = initialTokenBalance[_willOwner][_beneficiary.contractAddress];
        (uint256 allowance, uint256 balance) = getTokenStatus(_beneficiary.contractAddress, _willOwner);
        uint256 value = _beneficiary.value;
        if (initialBalance == 0) {
            uint256 amount = allowance > balance ? balance : allowance;
            initialTokenBalance[_willOwner][_beneficiary.contractAddress] = amount;
            return ((amount * value) / 100) > amount ? 0 : ((amount * value) / 100);
        }
        return ((value * initialBalance) / 100) > initialBalance ? 0 : ((value * initialBalance) / 100);
    }

    function withdraw () public onlyOwner {
        address _owner = owner();
        uint amount = address(this).balance;
        (bool sent, ) = _owner.call{value: amount}("");
        require(sent, "Failed to withdraw funds!!");
    }

    receive() external payable {}
    fallback() external payable {}
}
