// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface IMintable {
    function mint(address to, bytes memory data) external;
}
