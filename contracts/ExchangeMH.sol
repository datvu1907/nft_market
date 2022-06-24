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

    event CreateSellOrder(
        uint256 indexed _orderId,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _currency
    );
    event Buy(
        uint256 indexed _orderId,
        address indexed _buyer,
        address indexed seller,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _currency
    );
    event CancelSellOrder(
        uint256 indexed _orderId,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _currency
    );
    event AcceptOffer(
        address indexed _seller,
        address indexed _buyer,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price
    );

    struct Order {
        address tokenAddress;
        uint256 tokenId;
        address owner;
        uint256 amount;
        uint256 price;
        address currency;
    }

    // orderID => order
    mapping(uint256 => Order) public orders;

    Counters.Counter private _orderIdCounter;
    // addmin
    address private _adminAddress;
    // creator
    // contract address => tokenId => Creator
    mapping(address => mapping(uint256 => address)) private _creatorAddress;
    // percent fee of admin and creator
    uint256 private _adminFee = 0;
    uint256 private _creatorFee = 0;

    constructor() {}

    // sell (note: set _currency to 0 if seller want buyer to pay in SPC)
    // tokenId id of token erc1155
    // address token address which is used to pay
    function sell(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
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
            _price,
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
            order.price,
            order.currency
        );
    }

    function buyNative(uint256 _orderId, address _tokenAddress)
        external
        payable
    {
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
        uint256 adminFee = orders[_orderId].price * (_adminFee / 100);
        uint256 creatorFee = orders[_orderId].price * (_creatorFee / 100);
        if (_adminFee != 0) {
            TransferHelper.safeTransferETH(_adminAddress, adminFee);
        }

        if (_creatorFee != 0) {
            TransferHelper.safeTransferETH(_adminAddress, creatorFee);
        }

        TransferHelper.safeTransferETH(
            orders[_orderId].owner,
            orders[_orderId].price - adminFee - creatorFee
        );

        IERC1155(_tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            ""
        );

        delete orders[_orderId];

        emit Buy(
            _orderId,
            msg.sender,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            orders[_orderId].price,
            orders[_orderId].currency
        );
    }

    // Buy with ERC20 token
    function buy(uint256 _orderId, address _tokenAddress) external {
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

        IERC1155(_tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            ""
        );

        delete orders[_orderId];

        emit Buy(
            _orderId,
            msg.sender,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            orders[_orderId].price,
            orders[_orderId].currency
        );
    }

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

        delete orders[_orderId];

        emit CancelSellOrder(
            _orderId,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            orders[_orderId].amount,
            orders[_orderId].price,
            orders[_orderId].currency
        );
    }

    function acceptOffer(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _pricePerBox,
        address _currency,
        address _userOffer,
        address _tokenAddress
    ) external {
        require(
            IERC1155(_tokenAddress).balanceOf(msg.sender, _tokenId) >= _amount,
            "Not sufficient boxes"
        );

        IERC20(_currency).transferFrom(
            _userOffer,
            msg.sender,
            _pricePerBox * _amount
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
            _pricePerBox * _amount
        );
    }

    // set address of admin
    function setAdminAddress(address _admin) external onlyOwner {
        _adminAddress = _admin;
    }

    // set address of creator
    function setCreatorAddress(
        address _creator,
        address _tokenAddress,
        uint256 _tokenId
    ) external onlyOwner {
        _creatorAddress[_tokenAddress][_tokenId] = _creator;
    }

    // set admin fee
    function setAdminFee(uint256 _fee) external onlyOwner {
        _adminFee = _fee;
    }

    // set acreator fee
    function setCreatorFee(uint256 _fee) external onlyOwner {
        _creatorFee = _fee;
    }
}
