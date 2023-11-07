// SPDX-License-Identifier: MIT
// Creator: 3Engine
// Author: mranoncoder
pragma solidity ^0.8.20;

import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

/**
 * @dev Interface of ERC20
 */
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

/**
 * @dev Interface of Item Contract
 */
interface IItemsContract {
    function mint(address to, uint256 tokenId) external;

    function itemExists(uint256 itemId) external view returns (bool);

    function isMinter(address account) external view returns (bool);
}

/**
 * @dev Interface of Key Contract
 */
interface IKeyContract {
    struct KeyInfo {
        uint256 lootboxId;
        uint256 price;
        uint256 supply;
    }

    function ownerOf(uint256 tokenId) external view returns (address);

    function keyBoxID(uint256 tokenId) external view returns (uint256);

    function burnKey(uint256 keyId) external;

    function createKey(uint256 _lootboxId, uint256 _price) external;
}

contract LootBoxContract is ERC721A, ERC721AQueryable, ERC2981, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    IKeyContract public keyContract;
    string public BASE_URI;
    uint256 public currentMintedBoxId = 0;
    uint256 public currentLootBoxId = 0;

    struct Item {
        uint256 id;
        uint8 chance;
    }
    struct LootBox {
        uint256 id;
        uint256 supply;
        address itemsContract;
        Item[] items;
    }
    mapping(uint256 => uint256) public boxType;
    mapping(uint256 => LootBox) public lootBoxes;

    event BoxOpened(uint256 _boxID, uint256 _keyID, uint256 _itemID, address _to, address _itemContract);

    constructor(
        string memory _name,
        string memory _symbol,
        address minter,
        string memory _URI
    ) ERC721A(_name, _symbol) {
        BASE_URI = _URI;
        _grantRole(MINTER_ROLE, minter);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Creates a new LootBox with defined attributes and associated items.
     * @param _supply Maximum number of boxes that can be minted.
     * @param _itemsContract Address of the associated item contract.
     * @param _price Price of the LootBox in wei.
     * @param _itemIds Array of item IDs available in the LootBox.
     * @param _chances Array of chances for each item in the LootBox.
     */
    function createLootBox(
        uint256 _supply,
        address _itemsContract,
        uint256 _price,
        uint256[] memory _itemIds,
        uint8[] memory _chances
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_itemIds.length == _chances.length, "ITEM_MISMATCH");

        IItemsContract itemsContract = IItemsContract(_itemsContract);
        require(itemsContract.isMinter(address(this)), "NOT_ITEM_MINTER");

        for (uint8 i = 0; i < _itemIds.length; i++) {
            require(
                itemsContract.itemExists(_itemIds[i]),
                "ITEM_DOES_NOT_EXIST"
            );
        }

        uint8 totalChance;
        for (uint8 i = 0; i < _chances.length; i++) {
            totalChance += _chances[i];
        }
        require(totalChance <= 100, "INVALID_CHANCES");

        currentLootBoxId++;
        LootBox storage newBox = lootBoxes[currentLootBoxId];
        newBox.id = currentLootBoxId;
        newBox.supply = _supply;
        newBox.itemsContract = _itemsContract;

        for (uint8 i = 0; i < _itemIds.length; i++) {
            Item memory newItem = Item({id: _itemIds[i], chance: _chances[i]});
            newBox.items.push(newItem);
        }
        keyContract.createKey(currentLootBoxId, _price);
    }

    /**
     * @dev Mints a LootBox of a specified type to a recipient.
     * @param _to Address to receive the minted LootBox.
     * @param _lootBoxId ID of the LootBox type to mint.
     */
    function mintLootBox(
        address _to,
        uint256 _lootBoxId
    ) external onlyRole(MINTER_ROLE) {
        LootBox storage box = lootBoxes[_lootBoxId];
        require(box.supply >= 0, "OUT_OF_SUPPLY");

        box.supply--;

        _safeMint(_to, 1);
        boxType[currentMintedBoxId] = _lootBoxId;
        currentMintedBoxId++;
    }

    /**
     * @dev Allows the owner of a LootBox to open it and receive an item.
     * @param _boxID ID of the LootBox to open.
     * @param _keyId ID of the key required to open the LootBox.
     */
    function openBox(uint256 _boxID, uint256 _keyId) external {
        require(ownerOf(_boxID) == msg.sender, "NOT_THE_BOX_OWNER");
        require(keyContract.ownerOf(_keyId) == msg.sender, "NOT_THE_KEY_OWNER");
        uint256 lootBoxType = boxType[_boxID];

        require(
            keyContract.keyBoxID(_keyId) == lootBoxType,
            "KEY_DOES_NOT_MATCH_LOOTBOX"
        );
        LootBox storage box = lootBoxes[lootBoxType];

        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - 1), msg.sender)
                )
            ) % 100
        ) + 1;

        uint8 cumulativeChance = 0;
        for (uint8 i = 0; i < box.items.length; i++) {
            cumulativeChance += box.items[i].chance;
            if (random <= cumulativeChance) {
                keyContract.burnKey(_keyId);
                _burn(_boxID);
                uint256 itemId = box.items[i].id;
                IItemsContract(box.itemsContract).mint(msg.sender, itemId);
                emit BoxOpened(_boxID, _keyId, itemId, msg.sender, box.itemsContract);
                return;
            }
        }

        revert("FAILED_TO_SELECT_ITEM");
    }

    /**
     * @dev Retrieves all items associated with a specific LootBox.
     * @param _id ID of the LootBox.
     */
    function getLootBoxItems(
        uint256 _id
    ) external view returns (Item[] memory) {
        return lootBoxes[_id].items;
    }

    /**
     * @dev Sets the key contract address used for LootBox interactions.
     * @param _contractAddress Address of the key contract.
     */
    function addKeyContract(
        address _contractAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        keyContract = IKeyContract(_contractAddress);
    }

    /**
     * @dev Retrieves the remaining supply of a specific LootBox type.
     * @param _boxID ID of the LootBox type.
     */
    function getSupply(uint256 _boxID) external view returns (uint256) {
        LootBox storage box = lootBoxes[_boxID];
        return box.supply;
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
    ) public view override(ERC721A, IERC721A) returns (string memory) {
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
        override(ERC721A, ERC2981, AccessControl, IERC721A)
        returns (bool)
    {
        return
            ERC721A.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }
}
