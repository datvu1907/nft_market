//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./libraries/TransferHelper.sol";
// import "./interfaces/INFTMysteryBox.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/TransferHelper.sol";

import "hardhat/console.sol";

contract ExchangeMH is ERC1155Holder, Ownable {
    // using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;

    event CreateSellOrder(uint256 indexed _orderId, address indexed _seller, uint256 _tokenId, uint256 _amount, uint256 _price, address _currency);
    event Buy(uint256 indexed _orderId, address indexed _buyer, address indexed seller, uint256 _tokenId, uint256 _amount, uint256 _price, address _currency);
    event CancelSellOrder(uint256 indexed _orderId, address indexed _seller, uint256 _tokenId, uint256 _amount, uint256 _price, address _currency);
    event AcceptOffer(address indexed _seller, address indexed _buyer, uint256 _tokenId, uint256 _amount, uint256 _price);

    struct Order {
        uint256 tokenId;
        address owner;
        uint256 amount;
        uint256 price;
        address currency;
    }

    // orderID => order
    mapping(uint256 => Order) public orders;

    Counters.Counter private _orderIdCounter;
    address private _NFTMysteryBox;

    constructor(address NFTMysteryBox_) {
        _NFTMysteryBox = NFTMysteryBox_;
    }

    // sell (note: set _currency to 0 if seller want buyer to pay in SPC)
    function sell(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _currency
    ) external returns (uint256 orderId){
        require(
            IERC1155(_NFTMysteryBox).balanceOf(msg.sender, _tokenId) >=
                _amount,
            "Not sufficient boxes"
        );

        // create order
        _orderIdCounter.increment();
        orderId = _orderIdCounter.current();

        Order memory order = Order(
            _tokenId,
            msg.sender,
            _amount,
            _price,
            _currency
        );
        orders[orderId] = order;

        IERC1155(_NFTMysteryBox).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _amount,
            ""
        );

        emit CreateSellOrder(orderId, order.owner, order.tokenId, order.amount, order.price, order.currency);
    }

    function buyNative(uint256 _orderId) external payable {
        // check order status
        require(
            orders[_orderId].owner != address(0),
            "Order does not exist or is deleted"
        );
        require(
            msg.value == orders[_orderId].price,
            "Buyer did not send correct SPC amount"
        );
        require(
            orders[_orderId].currency == address(0),
            "Order requires being paid by erc20 currency, use buy() instead"
        );

        TransferHelper.safeTransferETH(
            orders[_orderId].owner, 
            orders[_orderId].price
        );
        
        IERC1155(_NFTMysteryBox).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            ""
        );

        delete orders[_orderId];

        emit Buy(_orderId, msg.sender, orders[_orderId].owner, orders[_orderId].tokenId, orders[_orderId].amount, orders[_orderId].price, orders[_orderId].currency);
    }

    function buy(uint256 _orderId) external {
        // check order status
        require(
            orders[_orderId].owner != address(0),
            "Order does not exist or is deleted"
        );
        require(
            orders[_orderId].currency != address(0),
            "Order requires being paid by native currency, use buyNative() instead"
        );
        require(
            IERC20(orders[_orderId].currency).balanceOf(msg.sender) >=
                orders[_orderId].price,
            "Buyer does not have enough ERC20 tokens"
        );

        TransferHelper.safeTransferFrom(
            orders[_orderId].currency,
            msg.sender,
            orders[_orderId].owner,
            orders[_orderId].price
        );

        IERC1155(_NFTMysteryBox).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            ""
        );

        delete orders[_orderId];

        emit Buy(_orderId, msg.sender, orders[_orderId].owner, orders[_orderId].tokenId, orders[_orderId].amount, orders[_orderId].price, orders[_orderId].currency);
    }

    function cancelSell(uint256 _orderId) external {
        require(
            orders[_orderId].owner != address(0),
            "Order does not exist"
        );
        require(
            orders[_orderId].owner == msg.sender,
            "Msg sender is not order 's owner"
        );

        IERC1155(_NFTMysteryBox).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            ""
        );

        delete orders[_orderId];

        emit CancelSellOrder(_orderId, orders[_orderId].owner, orders[_orderId].tokenId, orders[_orderId].amount, orders[_orderId].price, orders[_orderId].currency);
    }
    function acceptOffer(uint256 _tokenId, uint256 _amount, uint256 _pricePerBox, address _currency, address _userOffer) external {
        require(IERC1155(_NFTMysteryBox).balanceOf(msg.sender, _tokenId) >= _amount, 'Not sufficient boxes');

        IERC20(_currency).transferFrom(
            _userOffer,
            msg.sender,
            _pricePerBox * _amount
        );

         IERC1155(_NFTMysteryBox).safeTransferFrom(
            msg.sender,
            _userOffer,
            _tokenId,
            _amount,
            ""
        );
        emit AcceptOffer(msg.sender, _userOffer, _tokenId, _amount, _pricePerBox * _amount);
    }
}
