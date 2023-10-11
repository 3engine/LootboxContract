// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
interface IERC721Mintable {
    function mint(address to, uint256 tokenId) external;
    function isMinter(address account) external view returns (bool);
}
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


contract ItemsContract is ERC721A, ERC2981, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    IKeyContract public keyContract; 
    uint256 public currentMintedBoxId = 0; 
    uint256 public currentLootBoxId = 0;

    struct Item {
        uint256  id;
        uint8 chance; 
    }
    struct LootBox {
        uint256 id;
        uint256 supply;
        Item[] items;
        address itemContract;
    }    
    mapping(uint256 => uint256) public boxType; 
    mapping(uint256 => LootBox) public lootBoxes;
    string public BASE_URI;

    constructor(string memory name, string memory symbol,address minter, string memory _URI) ERC721A(_name, _symbol) {
        BASE_URI = _URI;
        _setupRole(MINTER_ROLE, minter);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function addKeyContract(address _contractAddress)external onlyRole(DEFAULT_ADMIN_ROLE) {
    keyContract = IKeyContract(_contractAddress);
    }

    function createLootBox(
    uint256 _supply,
    address _itemContract,
    uint256 _price,
    uint256[] memory _itemIds,
    uint8[] memory _chances
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_itemIds.length == _chances.length, "ITEM_MISMATCH");

    IERC721Mintable mintableContract = IERC721Mintable(_itemContract);
    require(mintableContract.isMinter(address(this)), "NOT_A_MINTER");

    uint8 totalChance;
    for (uint8 i = 0; i < _chances.length; i++) {
        totalChance += _chances[i];
    }
    require(totalChance <= 100, "INVALID_CHANCES");

    currentLootBoxId++;
    LootBox storage newBox = lootBoxes[currentLootBoxId];
    newBox.id = currentLootBoxId;
    newBox.supply = _supply;
    newBox.itemContract = _itemContract;

        for (uint8 i = 0; i < _itemIds.length; i++) {
            Item memory newItem = Item({
            id: _itemIds[i],
            chance: _chances[i]
            });
            newBox.items.push(newItem);
        }
    keyContract.createKey(currentLootBoxId, _price); 
    }   


    function getLootBoxItems(uint256 _id) external view returns(Item[] memory) {
        return lootBoxes[_id].items;
    }

    function mintLootBox(address _to, uint256 _lootBoxId) external onlyRole(MINTER_ROLE) {
        LootBox storage box = lootBoxes[_lootBoxId];
        require(box.supply > 0, "OUT_OF_SUPPLY");
    
        box.supply--;

        _safeMint(_to, 1);
        currentMintedBoxId++;
        boxType[currentMintedBoxId] = _lootBoxId;
    }

function openBox(uint256 _boxID, uint256 _keyId) external {
    require(ownerOf(_boxID) == msg.sender, "NOT_THE_OWNER");
    require(keyContract.ownerOf(_keyId) == msg.sender, "NOT_THE_KEY_OWNER");
    require(keyContract.keyBoxID(_keyId) == _boxID, "KEY_DOES_NOT_MATCH_LOOTBOX");
    
    uint256 lootBoxType = boxType[_boxID];
    LootBox storage box = lootBoxes[lootBoxType];

    uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), msg.sender))) % 100) + 1;

    uint8 cumulativeChance = 0;
    for (uint8 i = 0; i < box.items.length; i++) {
        cumulativeChance += box.items[i].chance;
        if (random <= cumulativeChance) {
            keyContract.burnKey(_keyId); 
            _burn(_boxID);
            uint256 itemId = box.items[i].id;
            IERC721Mintable(box.itemContract).mint(msg.sender, itemId);
            return;
        }
    }

    revert("Failed to select an item");
}

    function setBaseURI(string memory _URI) public onlyRole(DEFAULT_ADMIN_ROLE) {
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

    function withdraw(address _receiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance != 0, "BALANCE_IS_EMPTY");
        (bool sent, bytes memory data) = _receiver.call{value: balance}("");
        require(sent, "TX_FAILED");
    }

    function getSupply(uint256 _boxID) external view returns (uint256) {
        LootBox storage box = lootBoxes[_boxID];
        return box.supply;
    }
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    function grantMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    function revokeMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721A, ERC2981, AccessControl) returns (bool) {
        return
            ERC721A.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId)||
            AccessControl.supportsInterface(interfaceId);
    }
}