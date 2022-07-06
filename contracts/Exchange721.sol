//SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

import "./libraries/TransferHelper.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./abstracts/OwnerOperator.sol";
import "hardhat/console.sol";

contract Exchange721 is ERC721Holder, OwnerOperator {
    // using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    event CreateSellOrder(
        uint256 indexed _orderId,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _price,
        address _currency,
        address _tokenAddress
    );
    event Buy(
        uint256 indexed _orderId,
        address indexed _buyer,
        address indexed seller,
        uint256 _tokenId,
        uint256 _price,
        address _currency,
        address _tokenAddress
    );
    event CancelSellOrder(
        uint256 indexed _orderId,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _price,
        address _currency,
        address _tokenAddress
    );
    event UpdateSellOrder(
        uint256 indexed _orderId,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _oldPrice,
        uint256 _newPrice,
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

    event Bid(
        address indexed owner,
        address indexed winner,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        address _currency
    );

    struct Order {
        address tokenAddress;
        uint256 tokenId;
        address owner;
        uint256 price;
        address currency;
    }

    struct UserBid {
        address userAddress;
        uint256 price;
        uint256 bidId;
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

    function sell(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        address _currency
    ) external returns (uint256 orderId) {
        require(
            msg.sender == IERC721(_tokenAddress).ownerOf(_tokenId),
            "You are not the owner of NFT"
        );

        // create order
        _orderIdCounter.increment();
        orderId = _orderIdCounter.current();

        Order memory order = Order(
            _tokenAddress,
            _tokenId,
            msg.sender,
            _price,
            _currency
        );
        orders[orderId] = order;

        IERC721(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        emit CreateSellOrder(
            orderId,
            order.owner,
            order.tokenId,
            order.price,
            order.currency,
            order.tokenAddress
        );
    }

    // buy ERC721 with ERC20 token
    function buy(
        uint256 _orderId,
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
                orders[_orderId].price,
            "Buyer does not have enough ERC20 tokens"
        );
        // require(orders[_orderId].amount >= _amount, "Not enough box to");

        uint256 adminFee;
        uint256 creatorFee;

        if (payAdminFee && _adminFee != 0) {
            adminFee = orders[_orderId].price.div(100).mul(_adminFee);
            TransferHelper.safeTransferFrom(
                orders[_orderId].currency,
                msg.sender,
                _adminAddress,
                adminFee
            );
        }

        if (payCreatorFee && _creatorFee != 0) {
            creatorFee = orders[_orderId].price.div(100).mul(_creatorFee);
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
            orders[_orderId].price - adminFee - creatorFee
        );

        IERC721(orders[_orderId].tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId
        );

        delete orders[_orderId];

        emit Buy(
            _orderId,
            msg.sender,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            orders[_orderId].price,
            orders[_orderId].currency,
            orders[_orderId].tokenAddress
        );
    }

    function buyNative(
        uint256 _orderId,
        bool payAdminFee,
        bool payCreatorFee
    ) external payable {
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
        // require(orders[_orderId].amount >= _amount, "Not enough box to");

        uint256 adminFee;
        uint256 creatorFee;

        if (payAdminFee && _adminFee != 0) {
            adminFee = orders[_orderId].price.div(100).mul(_adminFee);
            TransferHelper.safeTransferETH(_adminAddress, adminFee);
        }

        if (payCreatorFee && _creatorFee != 0) {
            creatorFee = orders[_orderId].price.div(100).mul(_creatorFee);
            TransferHelper.safeTransferETH(
                _creatorOf[orders[_orderId].tokenAddress][
                    orders[_orderId].tokenId
                ],
                creatorFee
            );
        }
        TransferHelper.safeTransferETH(
            orders[_orderId].owner,
            orders[_orderId].price - adminFee - creatorFee
        );

        IERC721(orders[_orderId].tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId
        );

        emit Buy(
            _orderId,
            msg.sender,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            orders[_orderId].price,
            orders[_orderId].currency,
            orders[_orderId].tokenAddress
        );

        delete orders[_orderId];
    }

    function acceptOffer(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        address _currency,
        address _userOffer,
        bool payAdminFee,
        bool payCreatorFee
    ) external {
        require(
            IERC721(_tokenAddress).ownerOf(_tokenId) == msg.sender,
            "You are not the owner of NFT"
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

        IERC721(_tokenAddress).safeTransferFrom(
            msg.sender,
            _userOffer,
            _tokenId
        );
        emit AcceptOffer(
            msg.sender,
            _userOffer,
            _tokenId,
            1,
            _price,
            _tokenAddress
        );
    }

    // cancel sell
    function cancelSell(uint256 _orderId, address _tokenAddress) external {
        require(orders[_orderId].owner != address(0), "Order does not exist");
        require(
            orders[_orderId].owner == msg.sender,
            "Msg sender is not order 's owner"
        );

        IERC721(_tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId
        );

        emit CancelSellOrder(
            _orderId,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            orders[_orderId].price,
            orders[_orderId].currency,
            orders[_orderId].tokenAddress
        );

        delete orders[_orderId];
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

    // update order 's price ERC721 & ERC1155
    function updateOrder(uint256 _orderId, uint256 _newPrice) external {
        require(orders[_orderId].owner != address(0), "Order does not exist");
        require(
            orders[_orderId].owner == msg.sender,
            "Msg sender is not order 's owner"
        );

        uint256 oldPrice = orders[_orderId].price;
        orders[_orderId].price = _newPrice;

        emit UpdateSellOrder(
            _orderId,
            orders[_orderId].owner,
            orders[_orderId].tokenId,
            oldPrice,
            orders[_orderId].price,
            orders[_orderId].currency,
            orders[_orderId].tokenAddress
        );
    }

    // end Bid when the pice is higher than normal price
    function bidOverPrice(uint256 _orderId, uint256 _price) external {
        require(
            _price >= orders[_orderId].price,
            "Price must be equal or higher"
        );
        require(
            address(msg.sender).balance >= _price,
            "User do not have enough money"
        );

        IERC20(orders[_orderId].currency).transferFrom(
            msg.sender,
            orders[_orderId].owner,
            _price
        );

        IERC721(orders[_orderId].tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            orders[_orderId].tokenId
        );

        emit Bid(
            orders[_orderId].owner,
            msg.sender,
            orders[_orderId].tokenAddress,
            orders[_orderId].tokenId,
            _price,
            orders[_orderId].currency
        );
        delete orders[_orderId];
    }

    // end Bid when time is end
    function bidOverTime(uint256 _orderId, UserBid[] memory _listUserBid)
        external
        onlyOperator
        returns (UserBid memory)
    {
        address winner;
        uint256 finalPrice;
        uint256 winnerBidId;
        for (uint256 i = _listUserBid.length - 1; i >= 0; i--) {
            if (
                address(_listUserBid[i].userAddress).balance >=
                _listUserBid[i].price
            ) {
                winner = _listUserBid[i].userAddress;
                finalPrice = _listUserBid[i].price;
                winnerBidId = _listUserBid[i].bidId;
                break;
            }
        }

        IERC20(orders[_orderId].currency).transferFrom(
            winner,
            orders[_orderId].owner,
            finalPrice
        );
        IERC721(orders[_orderId].tokenAddress).safeTransferFrom(
            address(this),
            winner,
            orders[_orderId].tokenId
        );

        emit Bid(
            orders[_orderId].owner,
            winner,
            orders[_orderId].tokenAddress,
            orders[_orderId].tokenId,
            finalPrice,
            orders[_orderId].currency
        );
        delete orders[_orderId];
        return UserBid(winner, finalPrice, winnerBidId);
    }
}
