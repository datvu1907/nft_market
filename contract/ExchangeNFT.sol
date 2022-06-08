//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

// import "./interfaces/IERC721.sol";
// import "./interfaces/IStableToken.sol";
// import "./libraries/TransferHelper.sol";
import "./interfaces/INFTMysteryBox.sol";
// import "@openzeppelin/contracts/cryptography/ECDSA.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract ExchangeNFT is Ownable {
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

    enum RarityNumber {
        X1,
        X10
    }

    struct BoxAttribute {
        BoxType boxType;
        RarityNumber rarityNumber;
    }

    struct BoxItem {
        uint256 tokenID;
        address owner;
        uint256 price;
        Status status;        
    }

    BoxAttribute public tokenIDToAttribute[4] = [
        BoxAttribute(BoxType.BOX_NORMAL, RarityNumber.X1),
        BoxAttribute(BoxType.BOX_NORMAL, RarityNumber.X10),
        BoxAttribute(BoxType.BOX_RARE, RarityNumber.X1),
        BoxAttribute(BoxType.BOX_RARE, RarityNumber.X10),
    ];

    // BoxID => BoxItem value
    mapping(uint256 => BoxItem) boxItem;

    // Status => BoxIDs
    mapping(Status => uint256[]) boxItemListByStatus;

    // owner => tokenID => BoxIDs
    mapping(address => uint256 => uint256[]) public boxIDsOf;

    constructor(address _BoxNFT) {
        BoxNFT = _BoxNFT;
    }

    function sellAdmin(uint256 _tokenID, uint256 _value) external onlyOwner {
        INFTMysteryBox(BoxNFT).safeTransferFrom(msg.sender, address(this), _tokenID, _amount, '');
        // change status
        
    }
}
