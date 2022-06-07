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
    
    mapping(owner => tokenID => BoxItem[]) list
    // 1 person: 4 normalx1, 2 prices
// list[owner][1][0] // 1000
// list[owner][1][1].price //200 
    BoxAttribute public tokenIDToAttribute[4] = [
        BoxAttribute(BoxType.BOX_NORMAL, RarityNumber.X1),
        BoxAttribute(BoxType.BOX_NORMAL, RarityNumber.X10),
        BoxAttribute(BoxType.BOX_RARE, RarityNumber.X1),
        BoxAttribute(BoxType.BOX_RARE, RarityNumber.X10),
    ];

    BoxItem public BoxItemList[];

    constructor(address _BoxNFT) {
        BoxNFT = _BoxNFT;
    }

    function sell(uint256 _tokenID, uint256 _price, uint256 _amount) external {
        require(INFTMysteryBox(BoxNFT).balanceOf(msg.sender, _tokenID) >= _amount, "ExchangeNFT: balance is not sufficient");
        INFTMysteryBox(BoxNFT).safeTransferFrom(msg.sender, address(this), _tokenID, _amount, '');
    }
}
