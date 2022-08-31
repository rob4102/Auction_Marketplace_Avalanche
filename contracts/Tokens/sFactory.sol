// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import {ClonesUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "./erc721Static.sol";

contract sFactory {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /// Counter for current contract id upgraded
    CountersUpgradeable.Counter private atContract;

    /// Address for implementation of erc721Static to clone
    address public implementation;


    /// Initializes factory with address of implementation logic
    constructor(address _implementation) {
        implementation = _implementation;
    }

   
    function createEdition(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        string memory _imageUrl,
        uint256 _editionSize,
        uint256 _royaltyBPS
    ) external returns (uint256) {
        uint256 newId = atContract.current();
        address newContract = ClonesUpgradeable.cloneDeterministic(
            implementation,
            bytes32(abi.encodePacked(newId))
        );
        erc721Static(newContract).initialize(
            msg.sender,
            _name,
            _symbol,
            _description,
            _animationUrl,
            _imageUrl,
            _editionSize,
            _royaltyBPS
        );
        emit CreatedEdition(newId, msg.sender, _editionSize, newContract);
        // Returns the ID of the recently created minting contract
        // Also increments for the next contract creation call
        atContract.increment();
        return newId;
    }


    function getEditionAtId(uint256 editionId)
        external
        view
        returns (erc721Static)
    {
        return
            erc721Static(
                ClonesUpgradeable.predictDeterministicAddress(
                    implementation,
                    bytes32(abi.encodePacked(editionId)),
                    address(this)
                )
            );
    }


    event CreatedEdition(
        uint256 indexed editionId,
        address indexed creator,
        uint256 editionSize,
        address editionContractAddress
    );
}
