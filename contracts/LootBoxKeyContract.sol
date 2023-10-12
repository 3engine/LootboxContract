// SPDX-License-Identifier: MIT
// Creator: 3Engine
// Author: mranoncoder
pragma solidity ^0.8.9;

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
        address _lootBoxContractAddress
    ) ERC721A(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MODERATOR_ROLE, msg.sender);
        lootBoxContract = ILootBox(_lootBoxContractAddress);
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "CALLER_IS_NOT_USER");
        _;
    }

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

    function changeKeyPrice(
        uint256 _keyId,
        uint256 _price
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_keyId <= _keyIds, "INVALID_KEY");
        keyInfos[_keyId].price = _price;
    }

    function toggleSaleStatus(
        uint256 _keyId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_keyId <= _keyIds, "INVALID_KEY");
        keyInfos[_keyId].saleActive = !keyInfos[_keyId].saleActive;
    }

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

    function burnKey(uint256 _keyId) external onlyRole(MODERATOR_ROLE) {
        _burn(_keyId);
    }

    function isModerator(address _address) external view returns (bool) {
        return hasRole(MODERATOR_ROLE, _address);
    }

    function grantModeratorRole(
        address _address
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MODERATOR_ROLE, _address);
    }

    function revokeModeratorRole(
        address _address
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MODERATOR_ROLE, _address);
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
