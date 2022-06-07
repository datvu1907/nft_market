// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MysteryBox is ERC1155, Ownable {
    uint256 public constant GOLD = 3;
    uint256 public constant SILVER = 2;
    uint256 public constant NORMAL = 1;

    constructor() ERC1155("https://game.example/api/item/{id}.json") {}

    function mint(address exchangeContract) external onlyOwner {
        _mint(exchangeContract, NORMAL, 10**27, "");
        _mint(exchangeContract, SILVER, 10**27, "");
        _mint(exchangeContract, GOLD, 10**18, "");
    }
}
