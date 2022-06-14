//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/INFTMysteryBox.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract ExchangeMH is ERC1155Holder, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;

    enum Status {
        SALE,
        SOLD
    }

    event CreateSellOrder(uint256 _orderId, address indexed _seller, uint256 _tokenId, uint256 _amount, uint256 _pricePerBox);
    event Buy(uint256 _orderId, address indexed _buyer, uint256 _tokenId, uint256 _amount, uint256 _pricePerBox);
    event CancelSellOrder(uint256 _orderId, address indexed _seller, uint256 _tokenId, uint256 _amount, uint256 _remainingAmount, uint256 _pricePerBox);

    struct Order {
        uint256 tokenId;
        address owner;
        uint256 amount;
        uint256 remainingAmount;
        uint256 pricePerBox;
        Status status;
    }

    // orderID => order
    mapping(uint256 => Order) orders;

    Counters.Counter private _orderIdCounter;
    address private _NFTMysteryBox;
    address private _ERC20Token;

    constructor(address NFTMysteryBox_, address ERC20Token_) {
        _NFTMysteryBox = NFTMysteryBox_;
        _ERC20Token = ERC20Token_;
    }

    // sell function:
    function sell(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _pricePerBox
    ) external {
        require(
            INFTMysteryBox(_NFTMysteryBox).balanceOf(msg.sender, _tokenId) >=
                _amount,
            "Not sufficient boxes"
        );

        // create order
        _orderIdCounter.increment();
        uint256 orderId = _orderIdCounter.current();

        Order memory order = Order(
            _tokenId,
            msg.sender,
            _amount,
            _amount,
            _pricePerBox,
            Status.SALE
        );
        orders[orderId] = order;

        INFTMysteryBox(_NFTMysteryBox).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _amount,
            ""
        );

        emit CreateSellOrder(orderId, order.owner, order.tokenId, order.amount, order.pricePerBox);
    }

    function buy(uint256 _orderId) external {
        // check order status
        require(
            orders[_orderId].owner != address(0),
            "Order does not exist"
        );
        require(
            orders[_orderId].status == Status.SALE,
            "Order 's status is not SALE"
        );
        require(
            IERC20(_ERC20Token).balanceOf(msg.sender) >=
                orders[_orderId].pricePerBox,
            "Buyer does not have enough ERC20 tokens"
        );

        orders[_orderId].remainingAmount = orders[_orderId].remainingAmount - 1;
        if (orders[_orderId].remainingAmount == 0) {
            orders[_orderId].status = Status.SOLD;
        }

        IERC20(_ERC20Token).transferFrom(
            msg.sender,
            orders[_orderId].owner,
            orders[_orderId].pricePerBox
        );
        INFTMysteryBox(_NFTMysteryBox).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId,
            1,
            ""
        );

        emit Buy(_orderId, msg.sender, orders[_orderId].tokenId, 1, orders[_orderId].pricePerBox);
    }

    function cancelSell(uint256 _orderId) external {
        require(
            orders[_orderId].owner != address(0),
            "Order does not exist"
        );
        require(
            orders[_orderId].status == Status.SALE,
            "Order 's status is not SALE"
        );
        require(
            orders[_orderId].owner == msg.sender,
            "Msg sender is not order 's owner"
        );

        INFTMysteryBox(_NFTMysteryBox).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId,
            orders[_orderId].remainingAmount,
            ""
        );

        delete orders[_orderId];

        emit CancelSellOrder(_orderId, msg.sender, orders[_orderId].tokenId, orders[_orderId].amount, orders[_orderId].remainingAmount, orders[_orderId].pricePerBox);
    }
}
