//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

interface INFTMysteryBox {
    event ApprovalForAll(
        address indexed account,
        address indexed operator,
        bool approved
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Paused(address account);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );
    event URI(string value, uint256 indexed id);
    event Unpaused(address account);

    function balanceOf(address account, uint256 id)
        external
        view
        returns (uint256);

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        external
        view
        returns (uint256[] memory);

    function burn(
        address account,
        uint256 id,
        uint256 value
    ) external;

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) external;

    function exists(uint256 id) external view returns (bool);

    function isApprovedForAll(address account, address operator)
        external
        view
        returns (bool);

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function owner() external view returns (address);

    function pause() external;

    function paused() external view returns (bool);

    function renounceOwnership() external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function setApprovalForAll(address operator, bool approved) external;

    function setURI(string memory newuri) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function totalSupply(uint256 id) external view returns (uint256);

    function transferOwnership(address newOwner) external;

    function unpause() external;

    function uri(uint256) external view returns (string memory);
}