// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-URL: https://spdx.org/licenses/GPL-3.0-or-later.html
pragma solidity ^0.8.9;

import './TealswapERC20.sol';
import '../libraries/Math.sol';
import '../libraries/UQ112x112.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/ITealswapFactory.sol';
import '../interfaces/ITealswapPair.sol';
import '../interfaces/ITealswapCallee.sol';
import '../utils/Pausable.sol';

// <-- CHANGED: Pausable
contract TealswapPair is ITealswapPair, TealswapERC20, Pausable { // CHANGED -->
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public override factory;
    address public override token0;
    address public override token1;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public override price0CumulativeLast;
    uint public override price1CumulativeLast;
    uint public override kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint private unlocked = 1;

    // <!-- CHANGED
    uint public override feeBps;             // uniswap default = 30 (0.3%)
    uint public override protocolFeeDivider; // uniswap default = 6 (0.05%)
    // CHANGED -->

    modifier lock() {
        // <!-- CHANGED
        _requireNotPaused();
        // CHANGED -->

        require(unlocked == 1, 'Tealswap: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view override returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Tealswap: TRANSFER_FAILED');
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external override {
        require(msg.sender == factory, 'Tealswap: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
        
        // <!-- CHANGED
        // <--AUDIT FREE
        // the following 5 items will be modifed without further audits.
        // 1. feeBps
        // 2. protocolFeeDivider
        // 3. "LP ": string
        // 4. "NONE ": string
        // 5. fee tuple: (30, 6)
        // only values can be modified.

        // you can change the fee policies.
        // ex1. (100, 25) => swap fee: 1%, protocol fee: 0.04%
        // ex2. (30, 6) => swap fee: 0.3%, protocol fee: 0.05%
        // set default fee like uniswap v2.
        (feeBps, protocolFeeDivider) = (100, 25);

        name = string(
            abi.encodePacked(
                "LP ",
                IERC20(_token0).symbol(),
                "-",
                IERC20(_token1).symbol()
            )
        );
        // comments in this audit free region can be modified later without updating the audit report.
        // AUDIT FREE-->

        _setDomainSeperator();
        // CHANGED -->
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'Tealswap: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        unchecked {
            if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
                // * never overflows, and + overflow is desired
                price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        // <!-- CHANGED
        address feeTo = ITealswapFactory(factory).feeTo();
        feeOn = feeTo != address(0) && protocolFeeDivider > 0;
        // CHANGED -->
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0) * _reserve1);
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply * (rootK - rootKLast);
                    // <!-- CHANGED
                    uint denominator = rootK * (protocolFeeDivider - 1) + rootKLast;
                    // CHANGED -->
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external override lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;
        
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
        }
        require(liquidity > 0, 'Tealswap: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external override lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity * balance0 / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity * balance1 / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'Tealswap: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external override lock {
        require(amount0Out > 0 || amount1Out > 0, 'Tealswap: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'Tealswap: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'Tealswap: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) ITealswapCallee(to).TealswapCall(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'Tealswap: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            // 1000x - 3x -> 10000x - 30x
            uint _feeBps = feeBps;  // Gas savings
            uint balance0Adjusted = balance0 * 10000 - amount0In * _feeBps;
            uint balance1Adjusted = balance1 * 10000 - amount1In * _feeBps;
            require(balance0Adjusted * balance1Adjusted >= uint(_reserve0) * _reserve1 * 1E8, 'Tealswap: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external override lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

    // force reserves to match balances
    function sync() external override lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    // <!-- CHANGED
    function pause() external {
        require(msg.sender == factory, 'Tealswap: FORBIDDEN');
        _pause();
    }
    function unpause() external {
        require(msg.sender == factory, 'Tealswap: FORBIDDEN');
        _unpause();
    }
    function mintFee() public lock { // just execute _mintFee properly
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        
        bool feeOn = _mintFee(_reserve0, _reserve1);
        
        _update(balance0, balance1, _reserve0, _reserve1); // like sync
        if (feeOn) kLast = uint(reserve0) * reserve1;
    }
    function changeFee(uint _feeBps, uint _protocolFeeDivider) public {
        require(msg.sender == factory, 'Tealswap: FORBIDDEN');
        require(_feeBps < 10000, 'Bad feeBps');
        require(_protocolFeeDivider > 0, 'Bad protocolFeeDivider');

        mintFee(); // collect fee before new fee is adjusted.

        feeBps = _feeBps;
        protocolFeeDivider = _protocolFeeDivider;
    }
    // CHANGED -->
}
