// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../utils/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 private _decimals;
    address private _owner;
    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 initialSupply_) ERC20(name_, symbol_) {
        _mint(msg.sender, initialSupply_);
        _decimals = decimals_;
        _owner = msg.sender;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == _owner);
        _mint(to, amount);
    }
}