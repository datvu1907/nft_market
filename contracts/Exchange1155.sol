//SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

import "./libraries/TransferHelper.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./abstracts/OwnerOperator.sol";
import "hardhat/console.sol";

contract ExchangeMH is ERC1155Holder, OwnerOperator {
    // using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    event CreateSellOrder(
        uint256 indexed _orderId,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _currency,
        address _tokenAddress
    );
    event Buy(
        uint256 indexed _orderId,
        address indexed _buyer,
        address indexed seller,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _currency,
        address _tokenAddress
    );
    event CancelSellOrder(
        uint256 indexed _orderId,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _currency,
        address _tokenAddress
    );
    event UpdateSellOrder(
        uint256 indexed _orderId,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _oldPrice,
        uint256 _newPrice,
        address _currency,
        address _tokenAddress
    );
    event IncreaseAmount(
        uint256 indexed _orderId,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _oldAmount,
        uint256 _newAmount,
        uint256 _pricePerBox,
        address _currency,
        address _tokenAddress
    );
    event AcceptOffer(
        address indexed _seller,
        address indexed _buyer,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _tokenAddress
    );

    struct Order {
        address tokenAddress;
        uint256 tokenId;
        address owner;
        uint256 amount;
        uint256 pricePerBox;
        address currency;
    }

    // orderID => order
    mapping(uint256 => Order) public orders;

    Counters.Counter private _orderIdCounter;
    // addmin
    address private _adminAddress;
    // creator
    // contract address => tokenId => Creator
    mapping(address => mapping(uint256 => address)) private _creatorOf;
    // percent fee of admin and creator
    uint256 private _adminFee;
    uint256 private _creatorFee;

    constructor() {}

    // sell (note: set _currency to 0 if seller want buyer to pay in SPC)
    // tokenId id of token erc1155
    // address token address which is used to pay
    function sell(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _pricePerBox,
        address _currency
    ) external returns (uint256 orderId) {
        require(
            IERC1155(_tokenAddress).balanceOf(msg.sender, _tokenId) >= _amount,
            "Not sufficient boxes"
        );

        // create order
        _orderIdCounter.increment();
        orderId = _orderIdCounter.current();

        Order memory order = Order(
            _tokenAddress,
            _tokenId,
            msg.sender,
            _amount,
            _pricePerBox,
            _currency
        );
        orders[orderId] = order;

        IERC1155(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _amount,
            ""
        );

        emit CreateSellOrder(
            orderId,
            order.owner,
            order.tokenId,
            order.amount,
            order.pricePerBox,
            order.currency,
            order.tokenAddress
        );
    }

    function buyNative(
        uint256 _orderId,
        uint256 _amount,
        bool payAdminFee,
        bool payCreatorFee
    ) external payable {
        // check order status
        require(
            orders[_orderId].owner != address(0),
            "Order does not exist or is deleted"
        );
        require(
            msg.value == orders[_orderId].pricePerBox.mul(_amount),
            "Buyer did not send correct SPC amount"
        );
        require(
            orders[_orderId].currency == address(0),
            "Order requires being paid by erc20 currency, use buy() instead"
        );
        require(orders[_orderId].amount >= _amount, "Not enough box to");

        uint256 adminFee;
        uint256 creatorFee;

        if (payAdminFee && _adminFee != 0) {
            adminFee = orders[_orderId].pricePerBox.mul(_amount).div(100).mul(
                _adminFee
            );
            TransferHelper.safeTransferETH(_adminAddress, adminFee);
        }

        if (payCreatorFee && _creatorFee != 0) {
            creatorFee = orders[_orderId].pricePerBox.mul(_amount).div(100).mul(
                    _creatorFee
                );
            TransferHelper.safeTransferETH(
                _creatorOf[orders[_orderId].tokenAddress][
                    orders[_orderId].tokenId
                ],
                creatorFee
            );
        }

        TransferHelper.safeTransferETH(
            orders[_orderId].owner,
            orders[_orderId].pricePerBox.mul(_amount) - adminFee - creatorFee
        );

        IERC1155(orders[_orderId].tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId,
            _amount,
            ""
        );
        orders[_orderId].amount.sub(_amount);

        if (orders[_orderId].amount == 0) {
            delete orders[_orderId];
        }

        emit Buy(
            _orderId,
            msg.sender,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            orders[_orderId].pricePerBox,
            orders[_orderId].currency,
            orders[_orderId].tokenAddress
        );
    }

    // Buy with ERC20 token
    function buy(
        uint256 _orderId,
        uint256 _amount,
        bool payAdminFee,
        bool payCreatorFee
    ) external {
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
                orders[_orderId].pricePerBox.mul(_amount),
            "Buyer does not have enough ERC20 tokens"
        );
        require(orders[_orderId].amount >= _amount, "Not enough box to");

        uint256 adminFee;
        uint256 creatorFee;

        if (payAdminFee && _adminFee != 0) {
            adminFee = orders[_orderId].pricePerBox.mul(_amount).div(100).mul(
                _adminFee
            );
            TransferHelper.safeTransferFrom(
                orders[_orderId].currency,
                msg.sender,
                _adminAddress,
                adminFee
            );
        }

        if (payCreatorFee && _creatorFee != 0) {
            creatorFee = orders[_orderId].pricePerBox.mul(_amount).div(100).mul(
                    _creatorFee
                );
            TransferHelper.safeTransferFrom(
                orders[_orderId].currency,
                msg.sender,
                _creatorOf[orders[_orderId].tokenAddress][
                    orders[_orderId].tokenId
                ],
                creatorFee
            );
        }

        TransferHelper.safeTransferFrom(
            orders[_orderId].currency,
            msg.sender,
            orders[_orderId].owner,
            orders[_orderId].pricePerBox.mul(_amount) - adminFee - creatorFee
        );

        IERC1155(orders[_orderId].tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId,
            _amount,
            ""
        );

        emit Buy(
            _orderId,
            msg.sender,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            orders[_orderId].pricePerBox,
            orders[_orderId].currency,
            orders[_orderId].tokenAddress
        );
        orders[_orderId].amount.sub(_amount);

        if (orders[_orderId].amount == 0) {
            delete orders[_orderId];
        }
    }

    // cancel sell ERC1155
    function cancelSell(uint256 _orderId, address _tokenAddress) external {
        require(orders[_orderId].owner != address(0), "Order does not exist");
        require(
            orders[_orderId].owner == msg.sender,
            "Msg sender is not order 's owner"
        );

        IERC1155(_tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            ""
        );

        emit CancelSellOrder(
            _orderId,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            orders[_orderId].pricePerBox,
            orders[_orderId].currency,
            orders[_orderId].tokenAddress
        );

        delete orders[_orderId];
    }

    function acceptOffer(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _currency,
        address _userOffer,
        bool payAdminFee,
        bool payCreatorFee
    ) external {
        require(
            IERC1155(_tokenAddress).balanceOf(msg.sender, _tokenId) >= _amount,
            "Not sufficient boxes"
        );

        uint256 adminFee;
        uint256 creatorFee;

        if (payAdminFee && _adminFee != 0) {
            adminFee = _price.div(100).mul(_adminFee);
            TransferHelper.safeTransferFrom(
                _currency,
                _userOffer,
                _adminAddress,
                adminFee
            );
        }

        if (payCreatorFee && _creatorFee != 0) {
            creatorFee = _price.div(100).mul(_creatorFee);
            TransferHelper.safeTransferFrom(
                _currency,
                _userOffer,
                _creatorOf[_tokenAddress][_tokenId],
                creatorFee
            );
        }
        IERC20(_currency).transferFrom(
            _userOffer,
            msg.sender,
            _price.sub(adminFee).sub(creatorFee)
        );

        IERC1155(_tokenAddress).safeTransferFrom(
            msg.sender,
            _userOffer,
            _tokenId,
            _amount,
            ""
        );
        emit AcceptOffer(
            msg.sender,
            _userOffer,
            _tokenId,
            _amount,
            _price,
            _tokenAddress
        );
    }

    // set address of admin
    function setAdminAddress(address _admin) external onlyOperator {
        _adminAddress = _admin;
    }

    // set address of creator
    function setCreatorAddress(
        address _creator,
        address _tokenAddress,
        uint256 _tokenId
    ) external onlyOperator {
        _creatorOf[_tokenAddress][_tokenId] = _creator;
    }

    // set admin fee
    function setAdminFee(uint256 _fee) external onlyOperator {
        _adminFee = _fee;
    }

    // set acreator fee
    function setCreatorFee(uint256 _fee) external onlyOperator {
        _creatorFee = _fee;
    }

    // update order 's price  ERC1155
    function updateOrder(uint256 _orderId, uint256 _newPricePerBox) external {
        require(orders[_orderId].owner != address(0), "Order does not exist");
        require(
            orders[_orderId].owner == msg.sender,
            "Msg sender is not order 's owner"
        );

        uint256 oldPrice = orders[_orderId].pricePerBox;
        orders[_orderId].pricePerBox = _newPricePerBox;

        emit UpdateSellOrder(
            _orderId,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            oldPrice,
            orders[_orderId].pricePerBox,
            orders[_orderId].currency,
            orders[_orderId].tokenAddress
        );
    }

    function increaseAmount(uint256 _orderId, uint256 _amountToAdd) external {
        require(orders[_orderId].owner != address(0), "Order does not exist");
        require(
            orders[_orderId].owner == msg.sender,
            "Msg sender is not order 's owner"
        );
        require(
            IERC1155(orders[_orderId].tokenAddress).balanceOf(
                msg.sender,
                orders[_orderId].tokenId
            ) >= _amountToAdd,
            "Not sufficient boxes to add"
        );

        // increaseamount here
        uint256 oldAmount = orders[_orderId].amount;
        orders[_orderId].amount = orders[_orderId].amount.add(_amountToAdd);

        // transfer here
        IERC1155(orders[_orderId].tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            orders[_orderId].tokenId,
            _amountToAdd,
            ""
        );

        emit IncreaseAmount(
            _orderId,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            oldAmount,
            orders[_orderId].amount,
            orders[_orderId].pricePerBox,
            orders[_orderId].currency,
            orders[_orderId].tokenAddress
        );
    }
}
