//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "./interfaces.sol";

contract OptimalFixedSpreadLiquidation is IUniswapV2Callee {
    uint8 public constant health_factor_decimals = 18;

    // TODO: define constants used in the contract including ERC-20 tokens, Uniswap Pairs, Aave lending pools, etc. */
    //    *** Your code here ***
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public constant DAI_USDC_USDT_curvePool =
        0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address public constant uniswapFactory =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public constant aaveLendingPool =
        0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    IUniswapV2Factory public constant factory =
        IUniswapV2Factory(uniswapFactory);
    ILendingPool public constant lendingPool = ILendingPool(aaveLendingPool);
    ICurvePool public constant curvePool = ICurvePool(DAI_USDC_USDT_curvePool);

    address public constant USDC_WETH_Pair = 0x397FF1542f962076d0BFE58eA045FfA2d347ACa0;
    address public constant WETH_USDT_Pair = 0x06da0fd433C1A5d7a4faa01111c044910A184553;
    address public constant WBTC_WETH_Pair = 0xCEfF51756c56CeFFCA006cD410B03FFC46dd3a58;

    address public constant target = 0x59CE4a2AC5bC3f5F225439B2993b86B42f6d3e9F;
    address private immutable owner;
    // END TODO

    constructor() {
        // TODO: (optional) initialize your contract
        //   *** Your code here ***
        owner = msg.sender;
        // END TODO
    }

    // TODO: add a `receive` function so that you can withdraw your WETH
    //   *** Your code here ***
    receive() external payable {}
    // END TODO

    // required by the testing script, entry for your liquidation call
    function operate() external {
        // uint256 LT = currentLiquidationThreshold;
        // bytes4 CF = "0.5";
        // bytes4 LS = "0.05";

        // require(healthFactor < 1e18, "User is not liquidatable");

        // address WETH_USDT_Pair = factory.getPair(WETH, USDT);
        // address USDC_WETH_Pair = factory.getPair(USDC, WETH);
        
        
        // address WBTC_WETH_Pair = 0xCEfF51756c56CeFFCA006cD410B03FFC46dd3a58;

        // checkTarget();
        // revert();

        

        // uint256 amountInUSDC = 654363779479; // +2919580190499; //num of borrowed
        // uint256 amountInUSDC = 2919579787218;
        uint256 amountInWBTC = 1920877272;
        
        
        // IUniswapV2Pair(WETH_USDT_Pair).swap(0,653652703884,address(this),abi.encodePacked(uint256(1)));
        IUniswapV2Pair(WBTC_WETH_Pair).swap(amountInWBTC,0,address(this),abi.encodePacked(uint256(3)));
        IUniswapV2Pair(USDC_WETH_Pair).swap(2919569392158,0,address(this),abi.encodePacked(uint256(2)));

        uint256 profit = IERC20(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(profit);
        payable(owner).transfer(profit);
        // END TODO
    }

    // required by the swap
    function uniswapV2Call(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        
        uint256 round = abi.decode(data, (uint256));
        uint formerWETH = IERC20(WETH).balanceOf(address(this));
        uint amountToRepayETH;

        if(round == 1) {
            uint256 usdtGot = amount1;
            (uint reserve1, uint reserve0, ) = IUniswapV2Pair(WETH_USDT_Pair).getReserves();
            amountToRepayETH = getAmountIn(usdtGot,reserve1,reserve0);
            console.log("USDT Got:", usdtGot);
            console.log("ETH repay: ", amountToRepayETH);

            // uint256 X = 653652703884;
            SafeERC20.forceApprove(IERC20(USDT), aaveLendingPool, type(uint256).max);
            lendingPool.liquidationCall(LINK, USDT, target, usdtGot, false);
            (,,,,,uint256 healthFactor) = lendingPool.getUserAccountData(target);
            // console.log("collateral: ", totalCollateralETH);
            // console.log("debt: ", totalDebtETH);
            console.log("healthFactor: ", healthFactor);
            console.log("LINK get: ", IERC20(LINK).balanceOf(address(this)));

            uint amountLINK = IERC20(LINK).balanceOf(address(this));
            address LINK_WETH_Pair = 0xC40D16476380e4037e6b1A2594cAF6a6cc8Da967;
            (reserve0, reserve1, ) = IUniswapV2Pair(LINK_WETH_Pair).getReserves();
            uint256 amountTakenETH = getAmountOut(amountLINK*2/3, reserve0, reserve1);
            IERC20(LINK).transfer(LINK_WETH_Pair, amountLINK*2/3);
            IUniswapV2Pair(LINK_WETH_Pair).swap(0, amountTakenETH, address(this), new bytes(0));

            amountLINK = IERC20(LINK).balanceOf(address(this));
            LINK_WETH_Pair = factory.getPair(LINK, WETH);
            (reserve0, reserve1, ) = IUniswapV2Pair(LINK_WETH_Pair).getReserves();
            amountTakenETH = getAmountOut(amountLINK, reserve0, reserve1);
            IERC20(LINK).transfer(LINK_WETH_Pair, amountLINK);
            IUniswapV2Pair(LINK_WETH_Pair).swap(0, amountTakenETH, address(this), new bytes(0));

        }else if(round == 2) {
            uint256 usdcBorrowed = amount0;
            (uint reserve0, uint reserve1, ) = IUniswapV2Pair(USDC_WETH_Pair).getReserves();
            amountToRepayETH = getAmountIn(usdcBorrowed,reserve1,reserve0);
            IERC20(USDC).approve(DAI_USDC_USDT_curvePool, type(uint256).max);
            console.log("USDC Got:", usdcBorrowed);
            curvePool.exchange(1, 2, usdcBorrowed, 0);
            uint256 usdtGot = IERC20(USDT).balanceOf(address(this));
            console.log("USDT Got:", usdtGot);
            console.log("ETH repay: ", amountToRepayETH);

            SafeERC20.forceApprove(IERC20(USDT), aaveLendingPool, type(uint256).max);
            lendingPool.liquidationCall(WBTC, USDT, target, usdtGot, false);
            (,,,,,uint256 healthFactor) = lendingPool.getUserAccountData(target);
            // console.log("collateral: ", totalCollateralETH);
            // console.log("debt: ", totalDebtETH);
            console.log("healthFactor: ", healthFactor);
            console.log("WBTC get: ", IERC20(WBTC).balanceOf(address(this)));

            address WBTC_WETH_Pair = 0xCEfF51756c56CeFFCA006cD410B03FFC46dd3a58;
            uint256 amountWBTC = IERC20(WBTC).balanceOf(address(this));
            (reserve0, reserve1, ) = IUniswapV2Pair(WBTC_WETH_Pair).getReserves();
            uint amountTakenETH = getAmountOut(amountWBTC*2/3, reserve0, reserve1);
            IERC20(WBTC).transfer(WBTC_WETH_Pair, amountWBTC*2/3);
            IUniswapV2Pair(WBTC_WETH_Pair).swap(0, amountTakenETH, address(this), new bytes(0));

            amountWBTC = IERC20(WBTC).balanceOf(address(this));
            WBTC_WETH_Pair = factory.getPair(WBTC, WETH);
            (reserve0, reserve1, ) = IUniswapV2Pair(WBTC_WETH_Pair).getReserves();
            amountTakenETH = getAmountOut(amountWBTC, reserve0, reserve1);
            IERC20(WBTC).transfer(WBTC_WETH_Pair, amountWBTC);
            IUniswapV2Pair(WBTC_WETH_Pair).swap(0, amountTakenETH, address(this), new bytes(0));

        }else if(round == 3) {
            console.log("WBTC got: ", amount0);
            (uint reserve0, uint reserve1, ) = IUniswapV2Pair(WBTC_WETH_Pair).getReserves();
            amountToRepayETH = getAmountIn(amount0,reserve1,reserve0);
            SafeERC20.forceApprove(IERC20(WBTC), aaveLendingPool, type(uint256).max);
            lendingPool.liquidationCall(LINK, WBTC, target, amount0, false);
            (,,,,,uint256 healthFactor) = lendingPool.getUserAccountData(target);
            // console.log("collateral: ", totalCollateralETH);
            // console.log("debt: ", totalDebtETH);
            console.log("healthFactor: ", healthFactor);

            uint amountLINK = IERC20(LINK).balanceOf(address(this));
            address LINK_WETH_Pair = 0xC40D16476380e4037e6b1A2594cAF6a6cc8Da967;
            (reserve0, reserve1, ) = IUniswapV2Pair(LINK_WETH_Pair).getReserves();
            uint256 amountTakenETH = getAmountOut(amountLINK*2/3, reserve0, reserve1);
            IERC20(LINK).transfer(LINK_WETH_Pair, amountLINK*2/3);
            IUniswapV2Pair(LINK_WETH_Pair).swap(0, amountTakenETH, address(this), new bytes(0));

            amountLINK = IERC20(LINK).balanceOf(address(this));
            LINK_WETH_Pair = factory.getPair(LINK, WETH);
            (reserve0, reserve1, ) = IUniswapV2Pair(LINK_WETH_Pair).getReserves();
            amountTakenETH = getAmountOut(amountLINK, reserve0, reserve1);
            IERC20(LINK).transfer(LINK_WETH_Pair, amountLINK);
            IUniswapV2Pair(LINK_WETH_Pair).swap(0, amountTakenETH, address(this), new bytes(0));

        }
        
        // 2.3 repay
        //    *** Your code here ***
        console.log("ETH got: ", IERC20(WETH).balanceOf(address(this))-formerWETH);
        IERC20(WETH).transfer(msg.sender, amountToRepayETH);
        console.log("ETH earn: ", IERC20(WETH).balanceOf(address(this))-formerWETH);
        console.log("===================================================");
        // END TODO
    }

    function checkTarget() internal {
        printData(LINK, target);
        printData(WBTC, target);
        printData(WETH, target);
        printData(USDC, target);
        printData(USDT, target);
        printData(DAI, target);
    }

    function printData(address asset, address tar) internal{
        address ProtocalDP = 0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d;
        IProtocolDataProvider PDP = IProtocolDataProvider(ProtocalDP);
        (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,,,,,,
            bool usageAsCollateralEnabled
        ) = PDP.getUserReserveData(asset, tar);
        console.log(currentATokenBalance, currentStableDebt, currentVariableDebt, usageAsCollateralEnabled);
        (uint256 availableLiquidity,,,uint256 liquidityRate,,,,,,) = PDP.getReserveData(asset);
        console.log(availableLiquidity, liquidityRate);
    }

        // some helper function, it is totally fine if you can finish the lab without using these function
    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // some helper function, it is totally fine if you can finish the lab without using these function
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }
}
