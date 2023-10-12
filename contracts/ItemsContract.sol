// SPDX-License-Identifier: MIT
// Creator: 3Engine
// Author: mranoncoder
pragma solidity ^0.8.9;

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

contract ItemContract is ERC721A, ERC2981, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public currentitemId = 0;
    uint256 public currentMintedItems = 0;

    struct Item {
        uint256 id;
        string name;
    }

    mapping(uint256 => Item) public items;
    mapping(uint256 => uint256) public tokenType;
    string public BASE_URI;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721A(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function addItem(
        string memory _name
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        currentitemId++;
        Item storage newItem = items[currentitemId];
        newItem.id = currentitemId;
        newItem.name = _name;
    }

    function mint(address to, uint256 _itemID) external onlyRole(MINTER_ROLE) {
        require(_itemID <= currentitemId, "ITEMID_DONT_EXIST");
        _safeMint(to, 1);
        currentMintedItems++;
        tokenType[currentMintedItems] = _itemID;
    }

    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    function grantMinterRole(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    function revokeMinterRole(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }

    function setBaseURI(
        string memory _URI
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        BASE_URI = _URI;
    }

    function tokenURI(
        uint256 _id
    ) public view override(ERC721A) returns (string memory) {
        return
            bytes(BASE_URI).length > 0
                ? string(abi.encodePacked(BASE_URI, _toString(_id)))
                : "";
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function withdraw(address _receiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance != 0, "BALANCE_IS_EMPTY");
        (bool sent, bytes memory data) = _receiver.call{value: balance}("");
        require(sent, "TX_FAILED");
    }

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
