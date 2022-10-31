// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-URL: https://spdx.org/licenses/GPL-3.0-or-later.html
pragma solidity ^0.8.9;

import './TealswapPair.sol';
import '../interfaces/ITealswapFactory.sol';

contract TealswapFactory is ITealswapFactory {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor(address _feeToSetter) {
        // <--AUDIT FREE
        // the following item will be modifed without further audits.
        // 1. feeToSetter
        // it's value can be hardcoded regardeless of _feeToSetter.
        // ex1. feeToSetter = 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
        feeToSetter = 0x732508dA924f04a3895152fA4FE3dE176aC763A7;
        // AUDIT FREE-->
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'Tealswap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Tealswap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Tealswap: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(TealswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ITealswapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'Tealswap: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'Tealswap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    // <!-- CHANGED
    function pause(address tokenA, address tokenB) external {
        require(msg.sender == feeToSetter, 'Tealswap: FORBIDDEN');
        ITealswapPair(getPair[tokenA][tokenB]).pause();
    }
    function unpause(address tokenA, address tokenB) external {
        require(msg.sender == feeToSetter, 'Tealswap: FORBIDDEN');
        ITealswapPair(getPair[tokenA][tokenB]).unpause();
    }
    function changeFee(address tokenA, address tokenB, uint _feeBps, uint _protocolFeeDivider) external {
        require(msg.sender == feeToSetter, 'Tealswap: FORBIDDEN');
        ITealswapPair(getPair[tokenA][tokenB]).changeFee(_feeBps, _protocolFeeDivider);
    }
    // CHANGED -->
}
