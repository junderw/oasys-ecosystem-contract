// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-URL: https://spdx.org/licenses/GPL-3.0-or-later.html
pragma solidity ^0.8.9;

interface ITealswapCallee {
    function TealswapCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
