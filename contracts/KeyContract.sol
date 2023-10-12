// SPDX-License-Identifier: MIT
// Creator: 3Engine
// Author: mranoncoder
pragma solidity ^0.8.20;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

interface ILootBox {
    function getSupply(uint256 lootboxId) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract KeyContract is ERC721A, ERC2981, AccessControl {
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    ILootBox public lootBoxContract;
    string public BASE_URI;
    uint256 public _keyIds = 0;
    uint256 public currentMintedKeys = 0;

    struct KeyInfo {
        uint256 lootboxId;
        uint256 price;
        uint256 supply;
        bool saleActive;
    }
    mapping(uint256 => KeyInfo) public keyInfos;
    mapping(uint256 => uint256) public keyBoxID;

    constructor(
        string memory _name,
        string memory _symbol,
        address _lootBoxContractAddress,
        string memory _URI
    ) ERC721A(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MODERATOR_ROLE, _lootBoxContractAddress);
        lootBoxContract = ILootBox(_lootBoxContractAddress);
        BASE_URI = _URI;
    }

    /**
     * @dev Modifier that checks that caller is not an Contract
     */
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "CALLER_IS_NOT_USER");
        _;
    }

    /**
     * @dev Creates a new key with specified parameters.
     * @param _lootboxId The ID of the lootbox.
     * @param _price Price of the key.
     */
    function createKey(
        uint256 _lootboxId,
        uint256 _price
    ) external onlyRole(MODERATOR_ROLE) {
        _keyIds++;
        uint256 supply = lootBoxContract.getSupply(_lootboxId);

        keyInfos[_keyIds] = KeyInfo({
            lootboxId: _lootboxId,
            price: _price,
            supply: supply,
            saleActive: true
        });
    }

    /**
     * @dev Allows admins to change the price of a specified key.
     * @param _keyId ID of the key whose price needs to be changed.
     * @param _price New price for the key.
     */
    function changeKeyPrice(
        uint256 _keyId,
        uint256 _price
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_keyId <= _keyIds, "INVALID_KEY");
        keyInfos[_keyId].price = _price;
    }

    /**
     * @dev Toggles the sale status of a specified key.
     * @param _keyId ID of the key whose sale status needs to be toggled.
     */
    function toggleSaleStatus(
        uint256 _keyId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_keyId <= _keyIds, "INVALID_KEY");
        keyInfos[_keyId].saleActive = !keyInfos[_keyId].saleActive;
    }

    /**
     * @dev Allows users to purchase a specified key. Payment in Native Token is required.
     * @param _keyId ID of the key to be purchased.
     * @param _amount Amount of keys to be purchased.
     */
    function purchaseKey(
        uint256 _keyId,
        uint256 _amount
    ) external payable callerIsUser {
        require(_keyId <= _keyIds, "INVALID_KEY");
        require(keyInfos[_keyId].saleActive, "KEY_IS_NOT_ON_SALE");
        uint256 _price = keyInfos[_keyId].price * _amount;
        require(msg.value >= _price, "INCORRECT_ETHER");
        require(keyInfos[_keyId].supply > 0, "THIS_KEYS_ARE_SOLD_OUT");

        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(msg.sender, 1);
            keyBoxID[currentMintedKeys] = keyInfos[_keyId].lootboxId;
            currentMintedKeys++;
        }
        keyInfos[_keyId].supply -= _amount;

        if (msg.value > _price) {
            (bool sent, bytes memory data) = msg.sender.call{
                value: msg.value - _price
            }("");
            require(sent, "TX_FAILED");
        }
    }

    /**
     * @dev Allows moderators to burn a specified key.
     * @param _keyId ID of the key to be burned.
     */
    function burnKey(uint256 _keyId) external onlyRole(MODERATOR_ROLE) {
        _burn(_keyId);
    }

    /**
     * @dev Checks if an address has a moderator role.
     * @param _address Address to be checked.
     */
    function isModerator(address _address) external view returns (bool) {
        return hasRole(MODERATOR_ROLE, _address);
    }

    /**
     * @dev Grants the moderator role to a specified address.
     * @param _address Address to be granted the role.
     */
    function grantModeratorRole(
        address _address
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MODERATOR_ROLE, _address);
    }

    /**
     * @dev Revokes the moderator role from a specified address.
     * @param _address Address from which the role needs to be revoked.
     */
    function revokeModeratorRole(
        address _address
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MODERATOR_ROLE, _address);
    }

    /**
     * @dev Sets the base URI for tokens.
     * @param _URI The base URI to be set.
     */
    function setBaseURI(
        string memory _URI
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        BASE_URI = _URI;
    }

    /**
     * @dev Retrieves the full URI for a specific token ID.
     * @param _id ID of the token.
     */
    function tokenURI(
        uint256 _id
    ) public view override(ERC721A) returns (string memory) {
        return
            bytes(BASE_URI).length > 0
                ? string(abi.encodePacked(BASE_URI, _toString(_id)))
                : "";
    }

    /**
     * @dev Allows the admin to withdraw all ether from the contract.
     * @param _receiver Address to receive the withdrawn ether.
     */
    function withdraw(address _receiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance != 0, "BALANCE_IS_EMPTY");
        (bool sent, bytes memory data) = _receiver.call{value: balance}("");
        require(sent, "TX_FAILED");
    }

    /**
     * @dev Allows the admin to withdraw all of a specified token from the contract.
     * @param _tokenAddress Address of the token to be withdrawn.
     * @param _receiver Address to receive the withdrawn tokens.
     */
    function withdrawToken(
        address _tokenAddress,
        address _receiver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance != 0, "TOKEN_BALANCE_IS_EMPTY");
        bool sent = token.transfer(_receiver, balance);
        require(sent, "TOKEN_TX_FAILED");
    }

    /**
     * @dev Checks if the contract supports a given interface.
     * @param interfaceId ID of the interface to be checked.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721A, ERC2981, AccessControl)
        returns (bool)
    {
        return
            ERC721A.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }
}
