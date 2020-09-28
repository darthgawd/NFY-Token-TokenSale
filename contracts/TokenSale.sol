pragma solidity ^0.6.10;
import "./NFY.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// Contract that will keep track of funding and distribution for token sale
contract Funding {
    using SafeMath for uint;

    // Modifier that requires funding to not yet be active
    modifier fundingNotActive() {
        require(endFunding == 0, "Funding not active");
        _;
    }

    // Modifier that requires funding to be active
    modifier fundingActive() {
        require( endFunding > 0 && block.timestamp < endFunding && tokensAvailable > 0, "Funding must be active");
        _;
    }

    // Modifier that requires the funding to be over
    modifier fundingOver() {
        require((block.timestamp > endFunding || tokensAvailable == 0) && endFunding > 0, "Funding not over");
        _;
    }

    // Modifier that requires the teams tokens to be unlocked
    modifier teamTokensUnlocked() {
        require((block.timestamp > teamUnlockTime) && teamUnlockTime > 0, "Team's tokens are still locked");
        _;
    }

    // Struct that keeps track of buyer details
    struct Buyer {
        address investor;
        uint tokensPurchased;
        bool tokensClaimed;
        uint ethSent;
    }

    // Mapping that will link an address to their investment
    mapping(address => Buyer) buyers;

    // Variable that will keep track of the owner of the contract
    address owner;

    // Variable that will keep track of the ending time of the funding round
    uint public endFunding;

    // Variable that will keep track of the length of the funding round
    uint public saleLength;

    // Variable that will keep track of time sale started
    uint public startTime;

    // Variable that will keep track of the token price for days 1-4
    uint public tokenPrice1;

    // Variable that will keep track of token price for days 5-7
    uint public tokenPrice2;

    // Variable that will keep track of the tokens available to buy
    uint public tokensAvailable;

    // Variable that will keep track of the team's tokens
    uint public teamTokens;

    // Variable that will keep track of the time the team can withdraw their tokens
    uint public teamUnlockTime;

    // Variable that will keep track of how long team's tokens will be locked for
    uint public teamLockLength;

    // Bool that keeps track if team withdrew their tokens
    bool public teamWithdraw;

    // Variable that will store the token contract
    NFY public token;

    // Variable that will keep track of the tokens sold
    uint public tokensSold;

    // Variable that keeps track of ETH raised
    uint public ethRaised;

    bool public softCapMet = false;

    // Variable that will keep track of the contract address
    address public contractAddress = address(this);

    // Event that will be emitted when a purchase has been executed
    event PurchaseExecuted(uint _etherSpent, uint _tokensPurchased, address _purchaser);

    // Event that will be emitted when a investor withdraws tokens from fund
    event ClaimExecuted(uint _tokensSent, address _receiver);

    // Event that will emit how many tokens are on sale
    event TokensOnSale(uint _tokensOnSale);

    // Event that will emit how many tokens are for the team
    event AmountOfTeamTokens(uint _teamTokens);

    // Event that will emit when team withdraws their tokens
    event TeamWithdraw(uint _tokensSent, address _receiver);

    event SoftCapMet(string _msg, bool _softCapMet);

    // Constructor will set:
    // The address of token being sold
    // Length of funding - Seconds
    // Token Price
    // Tokens that are initially available
    // The tokens allotted  to team
    constructor( address _tokenAddress, uint _saleLength, uint _tokenPrice1, uint _tokenPrice2, uint _tokensAvailable, uint _teamTokens, uint _teamLockLength) Ownable() public {
        // Variable 'token' is the address of token being sold
        token = NFY(_tokenAddress);

        // Require a sale length greater than 0
        require(_saleLength > 0, "Length of sale should be more than 0");

        // Require more than 0 tokens to be initially available
        require(_tokensAvailable > 0, "Should be more than 0 tokens to go on sale");

        // Set the length of the funding round to time passed in
        saleLength = _saleLength;

        // Set the first token price as the price passed in
        tokenPrice1 = _tokenPrice1;

        // Set the second token price as price passed in
        tokenPrice2 = _tokenPrice2;

        // Set the initially available tokens as the amount passed in
        tokensAvailable = _tokensAvailable;

        // Set the amount of tokens the team will receive
        teamTokens = _teamTokens;

        // Set the length  the team's tokens will be locked
        teamLockLength = _teamLockLength;

        // Emit how many tokens are on sale and how many tokens are for team
        emit TokensOnSale(_tokensAvailable);
        emit AmountOfTeamTokens(_teamTokens);

    }

    // Call function to start the funding round.. Once called timer will start
    function startFunding() external onlyOwner() fundingNotActive() {
        startTime = block.timestamp;

        // Variable set to the current timestamp of block + length of funding round
        endFunding = block.timestamp + saleLength;

        // Variable set to the current timestamp of block + length of team's tokens locked
        teamUnlockTime = block.timestamp + teamLockLength;
    }

    // Function investor will call to buy tokens
    function buyTokens() public fundingActive() payable {

        if(block.timestamp.sub(startFunding) <= 345600 seconds){
            // Amount of tokens is the amount of ether sent / price
            uint _tokenAmount = msg.value.div(tokenPrice1);
        }

        else{
            uint _tokenAmount = msg.value.div(tokenPrice2);
        }

        // Require enough tokens are left for investor to buy
        require(
            _tokenAmount <= tokensAvailable,
            "Not enough tokens left"
        );

        // Variable keeping track of tokens sold will increase by amount of tokens bought
        tokensSold = tokensSold.add(_tokenAmount);

        // Variable keeping track of remaining tokens will decrease by amount of tokens sold
        tokensAvailable = tokensAvailable.sub(_tokenAmount);

        // Create a mapping to struct 'Buyer' that will set track of:
        // Address of the investor
        // Number of tokens purchased
        // That buyer has not claimed tokens
        // Total number of ether sent
        buyers[msg.sender].investor = msg.sender;
        buyers[msg.sender].tokensPurchased = buyers[msg.sender].tokensPurchased.add(_tokenAmount);
        buyers[msg.sender].tokensClaimed = false;
        buyers[msg.sender].ethSent = buyers[msg.sender].ethSent.add(msg.sender);

        ethRaised = ethRaised.add(msg.value);

        // Emit event that shows details of the current purchase
        emit PurchaseExecuted(msg.value, _tokenAmount, msg.sender);

        // If ETH raised is over 150 and soft cap has not been met yet
        if(ethRaised >= 150 ether && softCapMet == false) {
            softCapMet = true;
            emit SoftCapMet("Soft cap has been met", softCapMet);
        }
    }

    // Function that user will call to claim their purchased tokens once funding is over
    function claimTokens() external fundingOver()  {
        // Require that soft cap of 150 ETH has been met and no buy back
        require(softCapMet == true);

        // Variable 'buyer' of struct 'Buyer' will be used to access the buyers mapping
        Buyer storage buyer = buyers[msg.sender];

        // Require that the current msg.sender has invested
        require(buyer.tokensPurchased > 0, "No investment");

        // Require that the current msg.sender has not already withdrawn purchased tokens
        require(buyer.tokensClaimed == false, "Tokens already withdrawn");

        // Bool that keeps track of whether or not msg.sender has claimed tokens will be set to tue
        buyer.tokensClaimed = true;

        // Transfer all tokens purchased, to the investor
        token.transfer(buyer.investor, buyer.tokensPurchased);

        // Emit event that confirms details of current claim
        emit ClaimExecuted(buyer.tokensPurchased, msg.sender);
    }

    // Function investors will call if soft cap is not raised
    function investorGetBackEth() external fundingOver() {
        // Require soft cap was not met, investors get ETH back
        require(softCapMet == false, "Soft cap was met");
        require(buyers[msg.sender].ethSent > 0, "Did not invest or already claimed");

        uint withdrawAmount = buyers[msg.sender].ethSent;

        buyers[msg.sender].ethSent = 0;

        msg.sender.transfer(withdrawAmount);
    }

    // Function that will allow the team to withdraw their tokens
    function withdrawTeamTokens() external onlyOwner() teamTokensUnlocked() {
        // Require that soft cap of 150 ETH has been met and no buy back
        require(softCapMet == true);

        // Require that team has not withdrawn their tokens
        require(teamWithdraw == false, "Team has withdrawn their tokens");

        // Transfer team tokens to msg.sender (owner)
        token.transfer(msg.sender, teamTokens);

        // Set bool that tracks if team has withdrawn tokens to true
        teamWithdraw = true;

        // Emit event that confirms team has withdrawn their tokens
        emit TeamWithdraw(teamTokens, msg.sender);
    }

    // Function that will allow the owner to withdraw ethereum raised after funding is over
    function withdrawEth(uint amount) external onlyOwner() fundingOver() {
        // Require that soft cap of 150 ETH has been met and no buy back
        require(softCapMet == true);

        // Transfer the passed in amount ether to the msg.sender (owner)
        msg.sender.transfer(amount);
    }
}