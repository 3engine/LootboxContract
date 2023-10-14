// SPDX-License-Identifier: MIT
// Creator: 3Engine
// Author: mranoncoder
pragma solidity ^0.8.20;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract ItemsContract is ERC721A, ERC2981, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public BASE_URI;
    uint256 public currentitemId = 0;
    uint256 public currentMintedItems = 0;

    struct Item {
        uint256 id;
        string name;
    }

    mapping(uint256 => Item) public items;
    mapping(uint256 => uint256) public tokenType;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _URI
    ) ERC721A(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        BASE_URI = _URI;
    }

    /**
     * @dev Adds a new item to the collection
     * @param _name Name of the item to be added.
     */
    function addItem(
        string memory _name
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        currentitemId++;
        Item storage newItem = items[currentitemId];
        newItem.id = currentitemId;
        newItem.name = _name;
    }

    /**
     * @dev Mints a new token of a specified item type to a recipient.
     * @param to Address to receive the minted token.
     * @param _itemID ID of the item type to mint.
     */
    function mint(address to, uint256 _itemID) external onlyRole(MINTER_ROLE) {
        require(_itemID <= currentitemId, "ITEMID_DONT_EXIST");
        _safeMint(to, 1);
        tokenType[currentMintedItems] = _itemID;
        currentMintedItems++;
    }

    /**
     * @dev Checks if an address has the minter role.
     * @param account Address to be checked.
     */
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    /**
     * @dev Grants the minter role to a specified address.
     * @param account Address to be granted the role.
     */
    function grantMinterRole(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, account);
    }

    /**
     * @dev Revokes the minter role from a specified address.
     * @param account Address from which the role needs to be revoked.
     */
    function revokeMinterRole(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, account);
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
     * @dev Checks if a item with the specified ID exists.
     * @param itemId ID of the item to be checked.
     */
    function itemExists(uint256 itemId) public view returns (bool) {
        return items[itemId].id == itemId;
    }

    /**
     * @dev Checks if a token with the specified ID exists.
     * @param tokenId ID of the token to be checked.
     */
    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
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
