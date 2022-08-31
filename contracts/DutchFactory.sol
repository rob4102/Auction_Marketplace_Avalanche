pragma solidity ^0.6.9;
// ----------------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0

import "./Utils/Owned.sol";
import "./Utils/SafeMathPlus.sol";
import "./Utils/CloneFactory.sol";
import "../interfaces/IOwned.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IDutchAuction.sol";

contract DutchFactory is  Owned, CloneFactory {
    using SafeMathPlus for uint256;

    address public dutchAuctionTemplate;

    struct Auction {
        bool exists;
        uint256 index;
    }

    address public newAddress;
    uint256 public minimumFee = 0 ether;
    mapping(address => Auction) public isChildAuction;
    address[] public auctions;

    event DutchAuctionDeployed(address indexed owner, address indexed addr, address dutchAuction, uint256 fee);
    
    event CustomAuctionDeployed(address indexed owner, address indexed addr);

    event AuctionRemoved(address dutchAuction, uint256 index );
    event FactoryDeprecated(address newAddress);
    event MinimumFeeUpdated(uint oldFee, uint newFee);
    event AuctionTemplateUpdated(address oldDutchAuction, address newDutchAuction );

    function initDutchSwapFactory( address _dutchAuctionTemplate, uint256 _minimumFee) public  {
        _initOwned(msg.sender);
        dutchAuctionTemplate = _dutchAuctionTemplate;
        minimumFee = _minimumFee;
    }

    function numberOfAuctions() public view returns (uint) {
        return auctions.length;
    }

    function addCustomAuction(address _auction) public  {
        require(isOwner());
        require(!isChildAuction[_auction].exists);
        bool finalised = IDutchAuction(_auction).auctionEnded();
        require(!finalised);
        isChildAuction[address(_auction)] = Auction(true, auctions.length - 1);
        auctions.push(address(_auction));
        emit CustomAuctionDeployed(msg.sender, address(_auction));
    }
    
    function removeFinalisedAuction(address _auction) public  {
        require(isChildAuction[_auction].exists);
        bool finalised = IDutchAuction(_auction).auctionEnded();
        require(finalised);
        uint removeIndex = isChildAuction[_auction].index;
        emit AuctionRemoved(_auction, auctions.length - 1);
        uint lastIndex = auctions.length - 1;
        address lastIndexAddress = auctions[lastIndex];
        auctions[removeIndex] = lastIndexAddress;
        isChildAuction[lastIndexAddress].index = removeIndex;
        if (auctions.length > 0) {
            auctions.pop();
        }
    }

    function deprecateFactory(address _newAddress) public  {
        require(isOwner());
        require(newAddress == address(0));
        emit FactoryDeprecated(_newAddress);
        newAddress = _newAddress;
    }
    function setMinimumFee(uint256 _minimumFee) public  {
        require(isOwner());
        emit MinimumFeeUpdated(minimumFee, _minimumFee);
        minimumFee = _minimumFee;
    }

    function setDutchAuctionTemplate( address _dutchAuctionTemplate) public  {
        require(isOwner());
        emit AuctionTemplateUpdated(dutchAuctionTemplate, _dutchAuctionTemplate);
        dutchAuctionTemplate = _dutchAuctionTemplate;
    }

    function deployDutchAuction(
        address _token, 
        uint256 _tokenSupply, 
        uint256 _startDate, 
        uint256 _endDate, 
        address _paymentCurrency,
        uint256 _startPrice, 
        uint256 _minimumPrice, 
        address payable _wallet
    )
        public payable returns (address dutchAuction)
    {
        dutchAuction = createClone(dutchAuctionTemplate);
        isChildAuction[address(dutchAuction)] = Auction(true, auctions.length - 1);
        auctions.push(address(dutchAuction));
        require(IERC20(_token).transferFrom(msg.sender, address(this), _tokenSupply)); 
        require(IERC20(_token).approve(dutchAuction, _tokenSupply));
        IDutchAuction(dutchAuction).initDutchAuction(address(this), _token,_tokenSupply,_startDate,_endDate,_paymentCurrency,_startPrice,_minimumPrice,_wallet);
        emit DutchAuctionDeployed(msg.sender, address(dutchAuction), dutchAuctionTemplate, msg.value);
    }

    // footer functions
    function transferAnyERC20Token(address tokenAddress, uint256 tokens) public returns (bool success) {
        require(isOwner());
        return IERC20(tokenAddress).transfer(owner(), tokens);
    }
    receive () external payable {
        revert();
    }
}
