// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-URL: https://spdx.org/licenses/GPL-3.0-or-later.html
pragma solidity ^0.8.9;

import '../interfaces/ITealswapPair.sol';

library TealswapLibrary {
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'TealswapLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'TealswapLibrary: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        // <!-- CHANGED
        // <--AUDIT FREE
        // the following item will be modifed without further audits.
        // => hex'__32BYTES__'
        // __32BYTES__ can be replaced with new keccak256(bytecode of `TealswapPair`).
        // even a tiny change, such as modified runs-opt-option, can affect the ipfs hash.
        // as a result, the bytecode will be chagned.
        // see the following test script. (/scripts/deploy/core/validate-library.ts)
        pair = address(
            uint160(
                uint(keccak256(abi.encodePacked(
                    hex'ff',
                    factory,
                    keccak256(abi.encodePacked(token0, token1)),
                    hex'4c617d0b01ec3bdb54c1da74a5e8c2a1a6197da15cfaab3f15b42ef728438fe1' // init code hash
                )))
            )
        );
        // comments in this audit free region can be modified later without updating the audit report.
        // AUDIT FREE-->
        // CHANGED -->
    }

    // <-- CHANGED: for gas saving
    function _getReserves(address pair, bool reversed) private view returns (uint reserveA, uint reserveB){
        (uint reserve0, uint reserve1,) = ITealswapPair(pair).getReserves();
        (reserveA, reserveB) = reversed ? (reserve1, reserve0) : (reserve0, reserve1);
    }
    // CHANGED -->

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        // <-- CHANGED
        return _getReserves(pairFor(factory, tokenA, tokenB), tokenA != token0);
        // CHANGED -->
    }

    // <-- CHANGED: getFee was created to get feeBps of pair
    function getFee(address pair) internal view returns (uint feeBps) {
        return ITealswapPair(pair).feeBps();
    }
    // CHANGED -->

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'TealswapLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'TealswapLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // <-- CHANGED: added parameter `feeBps` to handle Pair with different feeBps
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint feeBps) internal pure returns (uint amountOut) { // CHANGED -->
        require(amountIn > 0, 'TealswapLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'TealswapLibrary: INSUFFICIENT_LIQUIDITY');

        // <-- CHANGED: feeBps unit changed: per mill -> basis point
        uint amountInWithFee = amountIn * (10000 - feeBps);
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 10000 + amountInWithFee;
        // CHANGED -->
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // <-- CHANGED: added parameter `feeBps` to handle Pair with different feeBps
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, uint feeBps) internal pure returns (uint amountIn) { // CHANGED -->
        require(amountOut > 0, 'TealswapLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'TealswapLibrary: INSUFFICIENT_LIQUIDITY');

        // <-- CHANGED: feeBps unit changed: per mill -> basis point
        uint numerator = reserveIn * amountOut * 10000;
        uint denominator = (reserveOut - amountOut) * (10000 - feeBps);
        // CHANGED -->
        amountIn = (numerator / denominator) + 1;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'TealswapLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            // <-- CHANGED
            (address token0,) = sortTokens(path[i], path[i + 1]);
            address pair = pairFor(factory, path[i], path[i + 1]);
            (uint reserveIn, uint reserveOut) = _getReserves(pair, path[i] != token0); // for gas savings
            uint feeBps = getFee(pair);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, feeBps);
            // CHANGED -->
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'TealswapLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            // <-- CHANGED
            (address token0,) = sortTokens(path[i - 1], path[i]);
            address pair = pairFor(factory, path[i - 1], path[i]);
            (uint reserveIn, uint reserveOut) = _getReserves(pair, path[i - 1] != token0); // for gas savings
            uint feeBps = getFee(pair);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, feeBps);
            // CHANGED -->
        }
    }
}