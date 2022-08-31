// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import {ClonesUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "./erc721Dynamic.sol";

contract dFactory {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    /// Counter for current contract id upgraded
    CountersUpgradeable.Counter private atContract;
    /// Address for implementation of erc721Dynamic to clone
    address public implementation;

  event CreatedEdition(
        uint256 indexed editionId,
        address indexed creator,
        uint256 editionSize,
        address editionContractAddress
    );

    
    /// Initializes factory with address of implementation logic
    constructor(address _implementation) {
        implementation = _implementation;
    }

   
    function createEdition(
        string memory _baseURI,
        string memory _name,
        string memory _symbol,
        string memory _description,
        uint256 _editionSize,
        uint256 _royaltyBPS
    ) external returns (uint256) {
        uint256 newId = atContract.current();
        address newContract = ClonesUpgradeable.cloneDeterministic(
            implementation,
            bytes32(abi.encodePacked(newId))
        );
        erc721Dynamic(newContract).initialize(
            msg.sender,
            _baseURI,
            _name,
            _symbol,
            _description,
            _editionSize,
            _royaltyBPS
        );
        emit CreatedEdition(newId, msg.sender, _editionSize, newContract);
        atContract.increment();
        return newId;
    }


    function getEditionAtId(uint256 editionId)
        external
        view
        returns (erc721Dynamic)
    {
        return
            erc721Dynamic(
                ClonesUpgradeable.predictDeterministicAddress(
                    implementation,
                    bytes32(abi.encodePacked(editionId)),
                    address(this)
                )
            );
    }


  
}
