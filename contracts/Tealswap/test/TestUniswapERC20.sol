// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '../core/TealswapERC20.sol';

contract TestUniswapERC20 is TealswapERC20 {
    constructor(uint _totalSupply) {
        _mint(msg.sender, _totalSupply);
    }
}
