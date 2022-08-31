// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import {IERC2981Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {SharedNFTLogic} from "./SharedNFTLogic.sol";
import {IEditionSingleMintable} from "./IEditionSingleMintable.sol";

contract erc721Dynamic is
    ERC721Upgradeable,
    IEditionSingleMintable,
    IERC2981Upgradeable,
    OwnableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    event PriceChanged(uint256 amount);
    event EditionSold(uint256 price, address owner);
    address contractAddress;

    // Base URI
    string public baseURI;  
    // contract description
    string public description;
    // Total size of edition that can be minted
    uint256 public editionSize;
    // Current token id minted
    CountersUpgradeable.Counter private atEditionId;
    // Royalty amount in bps
    uint256 royaltyBPS;
    // Addresses allowed to mint edition
    mapping(address => bool) allowedMinters;
    // Price for sale
    uint256 public salePrice;
    // NFT rendering logic contract
    SharedNFTLogic private immutable sharedNFTLogic;
    //* Constructor *//
    // Global constructor for factory
    
    constructor(address marketplaceAddress, SharedNFTLogic _sharedNFTLogic) {
        contractAddress = marketplaceAddress;
        sharedNFTLogic = _sharedNFTLogic;    
       


    }



    function initialize(
        address _owner,
        string memory _baseURI,
        string memory _name,
        string memory _symbol,
        string memory _description,
        uint256 _editionSize,
        uint256 _royaltyBPS
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init();
        transferOwnership(_owner);
        baseURI =  _baseURI;
        description = _description;
        editionSize = _editionSize;
        royaltyBPS = _royaltyBPS;
        atEditionId.increment();
    }


    /// @dev returns the number of minted tokens within the edition
    function totalSupply() public view returns (uint256) {
        return atEditionId.current() - 1;
    }


    function purchase() external payable returns (uint256) {
        require(salePrice > 0, "Not for sale");
        require(msg.value == salePrice, "Wrong price");
        address[] memory toMint = new address[](1);
        toMint[0] = msg.sender;
        emit EditionSold(salePrice, msg.sender);
        return _mintEditions(toMint);
    }

    /**
      @dev This sets a simple ETH sales price
           Setting a sales price allows users to mint the edition until it sells out.
           For more granular sales, use an external sales contract.
     */
    function setSalePrice(uint256 _salePrice) external onlyOwner {
        salePrice = _salePrice;
        emit PriceChanged(salePrice);
    }


    function withdraw() external onlyOwner {
        // No need for gas limit to trusted address.
        AddressUpgradeable.sendValue(payable(owner()), address(this).balance);
    }


    function _isAllowedToMint() internal view returns (bool) {
        if (owner() == msg.sender) {
            return true;
        }
        if (allowedMinters[address(0x0)]) {
            return true;
        }
        return allowedMinters[msg.sender];
    }


    function mintEdition(address to) external override returns (uint256) {
        require(_isAllowedToMint(), "Needs to be an allowed minter");
        address[] memory toMint = new address[](1);
        toMint[0] = to;
        return _mintEditions(toMint);
    }


    function mintEditions(address[] memory recipients)
        external
        override
        returns (uint256)
    {
        require(_isAllowedToMint(), "Needs to be an allowed minter");
        return _mintEditions(recipients);
    }


    function owner()
        public
        view
        override(OwnableUpgradeable, IEditionSingleMintable)
        returns (address)
    {
        return super.owner();
    }


    function setApprovedMinter(address minter, bool allowed) public onlyOwner {
        allowedMinters[minter] = allowed;
    }

  
    function updateEditionURLs(
        string memory _baseURI
    ) public onlyOwner {
        baseURI = _baseURI;
    }

    /// Returns the number of editions allowed to mint (max_uint256 when open edition)
    function numberCanMint() public view override returns (uint256) {
        if (editionSize == 0) {
            return type(uint256).max;
        }
        return editionSize + 1 - atEditionId.current();
    }

    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not approved");
        _burn(tokenId);
    }


    function _mintEditions(address[] memory recipients)
        internal
        returns (uint256)
    {
        uint256 startAt = atEditionId.current();
        uint256 endAt = startAt + recipients.length - 1;
        require(editionSize == 0 || endAt <= editionSize, "Sold out");
        while (atEditionId.current() <= endAt) {
            _mint(
                recipients[atEditionId.current() - startAt],
                atEditionId.current()
            );
            atEditionId.increment();
        }
        return atEditionId.current();
    }

    /**
      @dev Get URIs for edition NFT
      @return imageUrl,  animationUrl
     */
    function getURIs()
        public
        view
        returns (string memory)
    {
        return ( baseURI );
    }

    /**
        @dev Get royalty information for token
        @param _salePrice Sale price for the token
     */
    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        if (owner() == address(0x0)) {
            return (owner(), 0);
        }
        return (owner(), (_salePrice * royaltyBPS) / 10_000);
    }



  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI; 
  }

   // Token URI overrided 
  function tokenURI(uint256 tokenId) public view override virtual returns (string memory) {
    bytes32 tokenIdBytes;
    if (tokenId == 0) {
      tokenIdBytes = "0";
    } else {
      uint256 value = tokenId;
      while (value > 0) {
        tokenIdBytes = bytes32(uint256(tokenIdBytes) / (2 ** 8));
        tokenIdBytes |= bytes32(((value % 10) + 48) * 2 ** (8 * 31));
        value /= 10;
      }
    }

    bytes memory prefixBytes = bytes(baseURI);
    bytes memory tokenURIBytes = new bytes(prefixBytes.length + tokenIdBytes.length);

    uint8 i;
    uint8 index = 0;
        
    for (i = 0; i < prefixBytes.length; i++) {
      tokenURIBytes[index] = prefixBytes[i];
      index++;
    }
        
    for (i = 0; i < tokenIdBytes.length; i++) {
      tokenURIBytes[index] = tokenIdBytes[i];
      index++;
    }
        
    return string(tokenURIBytes);
  }


// Support Interface
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            type(IERC2981Upgradeable).interfaceId == interfaceId ||
            ERC721Upgradeable.supportsInterface(interfaceId);
    }
}
