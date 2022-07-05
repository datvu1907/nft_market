//SPDX-License-Identifier: MIT
pragma solidity 0.8.1;
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract OwnerOperator is Ownable {
    mapping(address => bool) public operators;

    constructor() Ownable() {}

    modifier operatorOrOwner() {
        require(
            operators[msg.sender] || owner() == msg.sender,
            "OwnerOperator: !operator, !owner"
        );
        _;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "OwnerOperator: !operator");
        _;
    }

    function addOperator(address operator) external virtual onlyOwner {
        require(
            operator != address(0),
            "OwnerOperator: operator is the zero address"
        );
        operators[operator] = true;
    }

    function removeOperator(address operator) external virtual onlyOwner {
        require(
            operator != address(0),
            "OwnerOperator: operator is the zero address"
        );
        operators[operator] = false;
    }
}
