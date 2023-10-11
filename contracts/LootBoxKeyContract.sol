// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface ILootBox {
    function getSupply(uint256 lootboxId) external view returns (uint256);
}

contract Key is ERC721A, AccessControl {
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    ILootBox public lootBoxContract; 
    uint256 public _keyIds = 0;
    uint256 public currentMintedKeys = 0; 

    struct KeyInfo {
        uint256 lootboxId;
        uint256 price;
        uint256 supply;
    }

    mapping(uint256 => KeyInfo) public keyInfos;
    mapping(uint256 => uint256) public keyBoxID;

    constructor(string memory _name, string memory _symbol, address _lootBoxContractAddress) ERC721A(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
        lootBoxContract = ILootBox(_lootBoxContractAddress);
    }
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function createKey(uint256 _lootboxId, uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _keyIds++;
        uint256 supply = lootBoxContract.getSupply(_lootboxId);

        keyInfos[_keyIds] = KeyInfo({
            lootboxId: _lootboxId,
            price: _price,
            supply: supply
        });
    }

    function changeKeyPrice(uint256 _keyId, uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_keyId <= _keyIds, "Key doesn't exist");
        keyInfos[_keyId].price = _price;
    }

    function purchaseKey(uint256 _keyId, uint256 _amount) external payable callerIsUser {
        require(_keyId <= _keyIds, "Key doesn't exist");
        require(keyInfos[_keyId].price * _amount == msg.value, "Incorrect Ether sent");
        require(keyInfos[_keyId].supply > 0, "No keys left for this lootbox");

        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(msg.sender, 1);
            keyBoxID[currentMintedKeys] = keyInfos[_keyId].lootboxId;
            currentMintedKeys++;
        }
        keyInfos[_keyId].supply -= _amount;
    }

    function burnKey(uint256 _keyId) external onlyRole(BURNER_ROLE) {
        _burn(_keyId);
    }    

    function isMinter(address _address) external view  returns (bool) {
        return hasRole(BURNER_ROLE, _address);
    }

    function grantBurnerRole(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BURNER_ROLE, _address);
    }

    function revokeBurnerRole(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(BURNER_ROLE, _address);
    }

    function supportsInterface(bytes4 _interfaceId) public view override(ERC721A, AccessControl) returns (bool) {
        return ERC721A.supportsInterface(_interfaceId) || AccessControl.supportsInterface(_interfaceId);
    }

}
