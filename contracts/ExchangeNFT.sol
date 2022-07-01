//SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

import "./interfaces/INFTMysteryBox.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Exchange is ERC1155Holder, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;

    enum Status {
        SALE,
        SOLD
    }

    enum UserStatus {
        SELL,
        BUY
    }

    // event CreateSellOrder(uint256 orderId, address indexed seller, uint256 tokenId, uint256 amount, uint256 price);
    // event Buy(uint256 orderId, );

    struct Order {
        uint256 tokenId;
        address owner;
        uint256 amount;
        uint256 remainingAmount;
        uint256 pricePerBox;
    }

    struct History {
        uint256 tokenId;
        address from;
        address to;
        uint256 amount;
        uint256 pricePerBox;
        uint256 time;
        UserStatus status;
    }

    struct OrderWithID {
        Order order;
        uint256 orderId;
    }

    // orderID => order
    mapping(uint256 => Order) orders;

    // Status => BoxIDs
    mapping(Status => EnumerableSet.UintSet) orderIdsByStatus;

    mapping(address => History[]) listUserHistory;

    Counters.Counter private _orderIdCounter;
    address private _NFTMysteryBox;
    address private _ERC20Token;

    constructor(address NFTMysteryBox_, address ERC20Token_) {
        _NFTMysteryBox = NFTMysteryBox_;
        _ERC20Token = ERC20Token_;
    }

    function getAllOrderByStatus(Status _status)
        external
        view
        returns (OrderWithID[] memory)
    {
        uint256 len = orderIdsByStatus[_status].length();
        OrderWithID[] memory orderList = new OrderWithID[](len);
        for (uint256 i = 0; i < len; i++) {
            orderList[i].order = orders[orderIdsByStatus[_status].at(i)];
            orderList[i].orderId = orderIdsByStatus[_status].at(i);
        }
        return orderList;
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

        Order memory item = Order(
            _tokenId,
            msg.sender,
            _amount,
            _amount,
            _pricePerBox
        );
        orders[orderId] = item;

        orderIdsByStatus[Status.SALE].add(orderId);

        INFTMysteryBox(_NFTMysteryBox).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _amount,
            ""
        );
    }

    function buy(uint256 _orderId) external {
        // check order status
        require(
            orderIdsByStatus[Status.SALE].contains(_orderId),
            "Order 's status is not SALE"
        );
        require(
            IERC20(_ERC20Token).balanceOf(msg.sender) >=
                orders[_orderId].pricePerBox,
            "Buyer does not have enough ERC20 tokens"
        );

        orders[_orderId].remainingAmount = orders[_orderId].remainingAmount - 1;
        if (orders[_orderId].remainingAmount == 0) {
            orderIdsByStatus[Status.SALE].remove(_orderId);
            orderIdsByStatus[Status.SOLD].add(_orderId);
        }
        address owner = orders[_orderId].owner;
        uint256 timeCreate = block.timestamp;

        //update history for seller
        listUserHistory[owner].push(
            History(
                orders[_orderId].tokenId,
                owner,
                msg.sender,
                1,
                orders[_orderId].pricePerBox,
                timeCreate,
                UserStatus.SELL
            )
        );

        // update history for buyer
        listUserHistory[msg.sender].push(
            History(
                orders[_orderId].tokenId,
                owner,
                msg.sender,
                1,
                orders[_orderId].pricePerBox,
                timeCreate,
                UserStatus.BUY
            )
        );

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
    }

    function cancelSell(uint256 _orderId) external {
        require(orders[_orderId].amount > 0, "Order doesn't exit");
        require(
            orderIdsByStatus[Status.SALE].contains(_orderId),
            "Order 's status is not SALE"
        );

        INFTMysteryBox(_NFTMysteryBox).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId,
            orders[_orderId].remainingAmount,
            ""
        );
        orderIdsByStatus[Status.SALE].remove(_orderId);
        delete orders[_orderId];
    }

    // return list token id, amount per token and user history
    function getListUserToken()
        external
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            History[] memory
        )
    {
        uint256[] memory listTokenId = INFTMysteryBox(_NFTMysteryBox)
            .getAllTokenIds();
        uint256[] memory listAmountToken = new uint256[](listTokenId.length);
        for (uint256 i = 0; i < listTokenId.length; i++) {
            listAmountToken[i] = INFTMysteryBox(_NFTMysteryBox).balanceOf(
                msg.sender,
                listTokenId[i]
            );
        }
        return (listTokenId, listAmountToken, listUserHistory[msg.sender]);
    }
}
