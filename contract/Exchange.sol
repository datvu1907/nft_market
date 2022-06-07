// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MysteryBox.sol";

contract Exchange is Ownable {
    struct BoxNFT {
        uint256 tokenID;
        uint256 price;
        address owner;
        bool isOpen;
    }

    uint256 public constant GOLD = 3;
    uint256 public constant SILVER = 2;
    uint256 public constant NORMAL = 1;

    uint256 public constant GOLD_PRICE = 10**21;
    uint256 public constant SILVER_PRICE = 10**19;
    uint256 public constant NORMAL_PRICE = 10**18;

    uint256 public constant TOTAL_NORMAL_BOX = 0;
    uint256 public constant TOTAL_SILVER_BOX = 0;
    uint256 public constant TOTAL_GOLD_BOX = 0;

    uint256 indexMarket = 0;
    mapping(uint256 => BoxNFT) listResellBox;

    mapping(uint256 => BoxNFT) listAuctionBox;

    MysteryBox mysteryBox;
    bool publicSaleBox = false;
    address public token;

    constructor(address tokenAddress) {
        token = tokenAddress;
        mysteryBox = MysteryBox(tokenAddress);
    }

    function openSale() public onlyOwner {
        publicSaleBox = true;
        mysteryBox.mint(address(this));
    }

    function buyBox(uint256 boxID, uint256 amount) public {
        require(publicSaleBox == true, "Can not buy Mystery Box");
        require(amount > 0, "Amount box must be greater than 0");
        require(boxID >= 1 && boxID <= 3, "Only 3 kind of box");
        if (boxID == 1) {
            IERC20(token).transferFrom(
                msg.sender,
                address(this),
                amount * NORMAL_PRICE
            );
        } else if (boxID == 2) {
            IERC20(token).transferFrom(
                msg.sender,
                address(this),
                amount * SILVER_PRICE
            );
        } else {
            IERC20(token).transferFrom(
                msg.sender,
                address(this),
                amount * GOLD_PRICE
            );
        }
        IERC1155(token).safeTransferFrom(
            address(this),
            msg.sender,
            boxID,
            amount,
            ""
        );
    }

    function resellBox(uint256 _id, uint256 _price) public {
        require(_price > 0, "Please submit price");
        IERC1155(token).safeTransferFrom(msg.sender, address(this), _id, 1, "");
        indexMarket++;
        listResellBox[indexMarket] = BoxNFT(_id, _price, msg.sender, false);
    }

    function buyResellBox(
        address _owner,
        uint256 _itemID,
        uint256 _price
    ) public {
        IERC20(token).transferFrom(msg.sender, _owner, _price);
        IERC1155(token).safeTransferFrom(
            address(this),
            msg.sender,
            listResellBox[_itemID].tokenID,
            1,
            ""
        );
        listResellBox[_itemID].owner = msg.sender;
    }

    function auctionBox(uint256 _id, uint256 _startPrice) public {
        require(_startPrice > 0, "Please submit price");
        IERC1155(token).safeTransferFrom(msg.sender, address(this), _id, 1, "");
        indexMarket++;
        listAuctionBox[indexMarket] = BoxNFT(
            _id,
            _startPrice,
            msg.sender,
            false
        );
    }
}
