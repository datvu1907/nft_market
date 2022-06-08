//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "./interfaces/IERC721.sol";
// import "./interfaces/IStableToken.sol";
// import "./libraries/TransferHelper.sol";
// import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "hardhat/console.sol";

contract ExchangeNFT is Ownable {
    address public BoxNFT;

    enum Status {
        NEW,
        SALE_NORMAL,
        SALE_AUCTION,
        SOLD,
        RESALE_NORMAL,
        RESALE_AUCTION
    }
    enum Rarity {
        S,
        SS,
        A,
        AA,
        B
    }
    enum BoxType {
        BOX_RARE,
        BOX_NORMAL
    }

    struct BoxExchange {
        uint256 id;
        uint256 amount;
        uint256 price;
        string name;
        Status status;
        Rarity rarity;
        uint256 rarityNumber;
        BoxType boxType;
    }

    struct BoxItem {
        uint256 id;
        address owner;
        uint256 price;
        Status status;
    }

    mapping(uint256 => BoxExchange) public listBoxExchange;

    // map list boxes base on status
    mapping(Status => BoxItem[]) public listBoxStatus;

    constructor(address _BoxNFT) {
        BoxNFT = _BoxNFT;
    }

    function mintToExchange(
        uint256 _id,
        string memory _name,
        uint8 _rarity,
        uint256 _rarityNumber,
        uint8 _boxType
    ) external onlyOwner {
        require(_rarity >= 0 && _rarity <= 4, "");
        require(_boxType >= 0 && _boxType <= 1, "");
        require(_rarityNumber == 1 || _rarityNumber == 10, "");
        // uint256 getAmount = ERC1155Supply(BoxNFT).totalSupply(_id);
        uint256 getAmount = 100;
        console.log(getAmount);
        listBoxExchange[_id] = BoxExchange(
            _id,
            getAmount,
            0,
            _name,
            Status.NEW,
            Rarity(_rarity),
            _rarityNumber,
            BoxType(_boxType)
        );
    }

    // add Box Sell to list
    function addToSaleNormal() external {
        listBoxStatus[Status(1)].push(
            BoxItem(
                1,
                0xa4adB90b738aA7205e5d79e8CF116F70e1087e3E,
                10000000000000,
                Status.SALE_NORMAL
            )
        );
    }

    function getListSellNormal(uint256 _status)
        external
        view
        returns (BoxItem[] memory)
    {
        return listBoxStatus[Status(_status)];
    }
}
