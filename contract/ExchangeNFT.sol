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
        Rarity Rarity;
        uint256 rarityNumber;
        BoxType boxType;
    }

    mapping(uint256 => BoxExchange) listBoxExchange;

    constructor(address _BoxNFT) {
        BoxNFT = _BoxNFT;
    }

    function mintToExchange(
        uint256 _id,
        string memory _name,
        uint8 _status,
        uint8 _rarity,
        uint256 _rarityNumber,
        uint8 _boxType
    ) external onlyOwner {
        require(_status >= 0 && _status <= 5, "");
        require(_rarity >= 0 && _rarity <= 4, "");
        require(_boxType >= 0 && _boxType <= 1, "");
        uint256 getAmount = ERC1155Supply(BoxNFT).totalSupply(_id);

        listBoxExchange[_id] = BoxExchange(
            _id,
            getAmount,
            0,
            _name,
            Status(_status),
            Rarity(_rarity),
            _rarityNumber,
            BoxType(_boxType)
        );
    }
}
