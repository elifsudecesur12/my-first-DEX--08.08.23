// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract AMMExample is IUniswapV2Callee, Ownable {
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Pair public pair;
    IERC20 public token;
    address public priceOracleAddress;
    
    constructor(address _uniswapV2Factory, address _token, address _priceOracleAddress) {
        uniswapV2Factory = IUniswapV2Factory(_uniswapV2Factory);
        token = IERC20(_token);
        priceOracleAddress = _priceOracleAddress;
        pair = IUniswapV2Pair(uniswapV2Factory.createPair(address(token), IUniswapV2Factory(_uniswapV2Factory).WETH()));
    }

    // Price Oracle kullanımı için arayüz belirtildi.
    IPriceOracle public priceOracle = IPriceOracle(priceOracleAddress);

    // Örnek bir PriceOracle arayüzü
    interface IPriceOracle {
        function getLatestPrice() external view returns (int);
    }

    // Uniswap swap işlemi için arayüz belirtildi.
    IUniswapRouterV2 public uniswapRouter;
    
    // UniswapRouterV2'nin arayüzü
    interface IUniswapRouterV2 {
        function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
    }

    // Swap işlemi için path belirtildi.
    address[] public path;

    function setUniswapRouter(address _router) external onlyOwner {
        uniswapRouter = IUniswapRouterV2(_router);
        path = [address(token), IUniswapV2Factory(uniswapV2Factory).WETH()];
    }

    function addLiquidity(uint256 amount) external onlyOwner {
        uint256 ethAmount = address(this).balance;
        require(ethAmount > 0, "No ETH to add");
        require(amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        int latestPrice = priceOracle.getLatestPrice();
        // Fiyat kullanımı ile ilgili daha fazla mantık ekleyebilirsiniz.
    }

    receive() external payable {}

    function uniswapV2Call(address, uint, uint, bytes calldata) external override {
        require(msg.sender == address(pair), "Only callable by Uniswap pair");
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No token balance to sell");

        uint256 ethAmount = address(this).balance;
        require(ethAmount > 0, "No ETH balance to sell");

        uint256 liquidity = pair.balanceOf(address(this));
        pair.burn(address(this));

        uint256 ethToSend = ethAmount + liquidity;
        payable(address(pair)).transfer(ethToSend);

        require(token.transfer(address(pair), balance), "Transfer failed");
    }

    function swapTokens(uint256 tokenAmount, address targetToken, uint deadline) external {
        require(tokenAmount > 0, "Amount must be greater than 0");
        require(targetToken != address(0), "Invalid target token address");
        require(uniswapRouter != IUniswapRouterV2(0), "Uniswap router is not set");

        // Transfer the input tokens from the user to the contract
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Transfer failed");
        
        uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(tokenAmount, 0, path, address(this), deadline);
        uint swappedAmount = amounts[amounts.length - 1];
        
        require(IERC20(targetToken).transfer(msg.sender, swappedAmount), "Transfer failed");
    }

    function getPairReserves() external view returns (uint256 ethReserve, uint256 tokenReserve) {
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        (ethReserve, tokenReserve) = pair.token0() == address(token) ? (reserve1, reserve0) : (reserve0, reserve1);
    }
}
