//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./libraries/TransferHelper.sol";
import "./interfaces/INFTMysteryBox.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/TransferHelper.sol";

contract ExchangeMH is ERC1155Holder, Ownable {
    // using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;

    enum Status {
        SALE,
        SOLD
    }

    event CreateSellOrder(uint256 _orderId, address indexed _seller, uint256 _tokenId, uint256 _amount, uint256 _pricePerBox);
    event Buy(uint256 _orderId, address indexed _buyer, uint256 _tokenId, uint256 _amount, uint256 _pricePerBox);
    event CancelSellOrder(uint256 _orderId, address indexed _seller, uint256 _tokenId, uint256 _amount, uint256 _remainingAmount, uint256 _pricePerBox);
    event AcceptOffer(address _seller, address _buyer, uint256 _tokenId, uint256 _amount, uint256 _price);

    struct Order {
        uint256 tokenId;
        address owner;
        uint256 amount;
        uint256 remainingAmount;
        uint256 pricePerBox;
        address currency;
        Status status;
    }

    // orderID => order
    mapping(uint256 => Order) private orders;

    Counters.Counter private _orderIdCounter;
    address private _NFTMysteryBox;
    address private _ERC20Token;

    constructor(address NFTMysteryBox_, address ERC20Token_) {
        _NFTMysteryBox = NFTMysteryBox_;
        _ERC20Token = ERC20Token_;
    }

    function getOrderInfo(uint256 _orderId) external view returns (Order memory) {
        return orders[_orderId];
    }

    // sell (currency: ERC20)
    function sell(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _pricePerBox
    ) external returns (uint256 orderId) {
        orderId = _sell(_tokenId, _amount, _pricePerBox, _ERC20Token);
    }

    // sell (currency: native token)
    function sellNative(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _pricePerBox
    ) external returns (uint256 orderId) {
        orderId = _sell(_tokenId, _amount, _pricePerBox, address(0));
    } 

    // sell internal
    function _sell(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _pricePerBox,
        address _currency
    ) internal returns (uint256 orderId){
        require(
            INFTMysteryBox(_NFTMysteryBox).balanceOf(msg.sender, _tokenId) >=
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
            _amount,
            _pricePerBox,
            _currency,
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

    function buyNative(uint256 _orderId) external payable {
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
            msg.value == orders[_orderId].pricePerBox,
            "Buyer did not send correct SPC amount"
        );
        require(
            orders[_orderId].currency == address(0),
            "Order must be paid by native currency"
        );

        orders[_orderId].remainingAmount = orders[_orderId].remainingAmount - 1;
        if (orders[_orderId].remainingAmount == 0) {
            orders[_orderId].status = Status.SOLD;
        }

        TransferHelper.safeTransferETH(
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
        require(
            orders[_orderId].currency != address(0),
            "Order must not be paid by native currency"
        );

        orders[_orderId].remainingAmount = orders[_orderId].remainingAmount - 1;
        if (orders[_orderId].remainingAmount == 0) {
            orders[_orderId].status = Status.SOLD;
        }

        TransferHelper.safeTransferFrom(
            _ERC20Token,
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
    function acceptOffer(uint256 _tokenId, uint256 _amount, uint256 _pricePerBox, address _userOffer) external {
        require(INFTMysteryBox(_NFTMysteryBox).balanceOf(msg.sender, _tokenId) >= _amount, 'Not sufficient boxes');

        IERC20(_ERC20Token).transferFrom(
            _userOffer,
            msg.sender,
            _pricePerBox * _amount
        );

         INFTMysteryBox(_NFTMysteryBox).safeTransferFrom(
            msg.sender,
            _userOffer,
            _tokenId,
            _amount,
            ""
        );
        emit AcceptOffer(msg.sender, _userOffer, _tokenId, _amount, _pricePerBox * _amount);
    }
}
