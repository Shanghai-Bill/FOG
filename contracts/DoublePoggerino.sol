

pragma solidity ^0.5.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";


contract DoublePoggerino is ERC20, ERC20Pausable {
    using SafeMath for uint256;
    
    event FeeUpdated(uint8 feeDecimals, uint32 feePercentage);
    event RewardsUpdate(uint32 fogRewardPercentage);
    event LocksUpdate(uint32 fogLockPercentage, uint32 tokenLockPercentage);
    event LockLiquidity(uint256 tokenAmount, uint256 ethAmount);
    event BurnLiquidity(uint256 lpTokenAmount);
    event RewardedFog(uint256 tokenAmount);
    event RewardedEth(uint256 ethAmount);
    event BoughtTokenLP(uint256 tokenAmount, uint256 ethAmount);
    event TokenAddressUpdate(address tokenAddress);
    event TokenAddressPairUpdate(address tokenAddressPair);
    event WethAddressUpdate(address wethAddress);
    
    address public uniswapV2Router;
    address public uniswapV2Pair;
    address public tokenAddress;
    address public tokenAddressPair;
    address public wethAddress;
    
    uint8 public feeDecimals;
    uint32 public feePercentage;
    uint32 public liquidityRewardPercentage;
    uint32 public fogRewardPercentage;
    uint32 public fogLockPercentage;
    uint32 public tokenLockPercentage;
   
   
    
    mapping ( address => uint256 ) public balances; 

    function _transfer(address from, address to, uint256 amount) internal whenNotPaused {
        // calculate liquidity lock amount
        // *tokenAddress and *tokenAddressPair 
        // refer to the set token that Fog buys/adds LP
        // all *token* references in this contract pertain 
        // to the set ERC20 token via the Fog contract
        if (from != address(this)) {
            
             // calculate the number of tokens to take as a fee
        uint256 fogToAddDensity = calculateVisabilityFee(
            amount,
            feeDecimals,
            feePercentage
        );
        
            uint256 fogToTransfer = amount.sub(fogToAddDensity);
            super._transfer(from, address(this), fogToAddDensity);
            super._transfer(from, to, (fogToTransfer));
        }
        else {
            super._transfer(from, to, amount);
        }
    }

    // receive eth from uniswap swap
    function () external payable {}

    function fogRollingIn(uint256 _fogDensity) public {
        // lockable supply is the token balance of this contract
        require(_fogDensity <= balanceOf(address(this)), "ERC20TransferLiquidityLock::lockLiquidity: lock amount higher than lockable balance");
        require(_fogDensity != 0, "ERC20TransferLiquidityLock::lockLiquidity: lock amount cannot be 0");
       
            // Fog Lock LP
            uint256 fogToLockAmount = calculateVisabilityFee(
            _fogDensity,
            feeDecimals,
            fogLockPercentage
        );
        
            fogLockSwap(fogToLockAmount);
        
            uint256 fogRemainder = _fogDensity.sub(fogToLockAmount);
            
            // Fog LP Provider Rewards 
            uint256 fogRewardsAmount = calculateVisabilityFee(
            fogRemainder,
            feeDecimals,
            fogRewardPercentage
        );
            
            divideRewards(fogRewardsAmount);
            
            uint256 tokenRemainder = fogRemainder.sub(fogRewardsAmount);
            
            // Amount to buy LIQ LP
            uint256 tokenBuyAmount = calculateVisabilityFee(
            tokenRemainder,
            feeDecimals,
            tokenLockPercentage
        );
            
            buyAndLockToken(tokenBuyAmount);
            
           
    }
            
        
       //fogLock
       
       function fogLockSwap(uint256 fogToLockAmount) private {
       
        uint256 fogLockSplitEth = fogToLockAmount.div(2);
        uint256 otherHalfOfFogPair = fogToLockAmount.sub(fogLockSplitEth);
        uint256 ethBalanceBeforeFogLock = address(this).balance;
    swapFogTokensForEth(fogLockSplitEth);
        uint newBalance = address(this).balance.sub(ethBalanceBeforeFogLock);

    addLiquidity(otherHalfOfFogPair, newBalance);
    emit LockLiquidity(otherHalfOfFogPair, newBalance);
    
      }
    
    
        // Rewards 
    function divideRewards(uint256 _fogRewardsAmount) private { 
        
        uint256 fogSwapEth = _fogRewardsAmount.div(2);
        uint256 otherHalfFog = _fogRewardsAmount.sub(fogSwapEth);
        uint256 ethBalanceBeforeFogSwap = address(this).balance;
    swapFogTokensForEth(fogSwapEth);
        uint256 ethReceived = address(this).balance.sub(ethBalanceBeforeFogSwap);
            
    _rewardLiquidityProviders(otherHalfFog);
            
    _rewardLiquidityProvidersETH(ethReceived);
        
    }   
      
        // TokenSplit
    function buyAndLockToken(uint256 _tokenBuyAmount) private {
        
    uint256 amountToSwapEth = _tokenBuyAmount;
    
        uint256 ethBalanceBeforTokenEthSwap = address(this).balance;
    swapFogTokensForEth(amountToSwapEth);
        uint256 ethReceivedForToken = address(this).balance.sub(ethBalanceBeforTokenEthSwap);

    uint256 amountToBuyToken = ethReceivedForToken.div(2);
    uint256 amountEthForTokenLP = ethReceivedForToken.sub(amountToBuyToken);
        
        // check for any liq in contract already
        uint256 balanceOfTokenBeforeSwap = ERC20(tokenAddress).balanceOf(address(this));
    swapEthForERC20token(amountToBuyToken);
        uint256 tokenRecieved = ERC20(tokenAddress).balanceOf(address(this)).sub(balanceOfTokenBeforeSwap);

        // Add Liq liquidity 
    addERC20liquidity(tokenRecieved, amountEthForTokenLP);
    emit BoughtTokenLP(tokenRecieved, amountEthForTokenLP); 

     }  

    // external util so anyone can easily distribute rewards
    // must call lockLiquidity first which automatically
    // calls _rewardLiquidityProviders & _rewardLiquidityProvidersETH
    function rewardLiquidityProviders() external {
        // lock everything that is lockable;
        fogRollingIn(balanceOf(address(this)));
        
    }

    function _rewardLiquidityProviders(uint256 _fogToRewards) private {
        super._transfer(address(this), uniswapV2Pair, _fogToRewards);
        IUniswapV2Pair(uniswapV2Pair).sync();
        emit RewardedFog(_fogToRewards);
    }
     
   function _rewardLiquidityProvidersETH(uint256 _ethReceived) public {
       IWETH(wethAddress).deposit.value(_ethReceived)();
       ERC20(wethAddress).transfer(uniswapV2Pair, _ethReceived);
       IUniswapV2Pair(uniswapV2Pair).sync();

    }
    
    function burnLiquidity() external {
        uint256 balance = ERC20(uniswapV2Pair).balanceOf(address(this));
        require(balance != 0, "ERC20TransferLiquidityLock::burnLiquidity: burn amount cannot be 0");
        ERC20(uniswapV2Pair).transfer(address(0), balance);
        emit BurnLiquidity(balance);
    }

    function swapFogTokensForEth(uint256 tokenAmount) private {
        address[] memory uniswapPairPath = new address[](2);
        uniswapPairPath[0] = address(this);
        uniswapPairPath[1] = IUniswapV2Router02(uniswapV2Router).WETH();

        _approve(address(this), uniswapV2Router, tokenAmount);

        IUniswapV2Router02(uniswapV2Router)
            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                uniswapPairPath,
                address(this),
                block.timestamp
            );
    }
    
    function swapEthForERC20token(uint256 ethAmount) private {
        address[] memory uniswapPairPath = new address[](2);
        uniswapPairPath[0] = IUniswapV2Router02(uniswapV2Router).WETH();
        uniswapPairPath[1] = tokenAddress;
        
        ERC20(wethAddress).approve(uniswapV2Router, ethAmount);
        
        
         IUniswapV2Router02(uniswapV2Router)
            .swapExactETHForTokensSupportingFeeOnTransferTokens
            .value(ethAmount)(
        0,
        uniswapPairPath,
        address(this),
        block.timestamp
    ); 
}
    
    
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), uniswapV2Router, tokenAmount);

        IUniswapV2Router02(uniswapV2Router)
            .addLiquidityETH
            .value(ethAmount)(
                address(this),
                tokenAmount,
                0,
                0,
                address(this),
                block.timestamp
            );
     
    }
    
     function addERC20liquidity(uint256 tokenAmount, uint256 ethAmount) private {
        ERC20(wethAddress).approve(uniswapV2Router, ethAmount);
        ERC20(tokenAddress).approve(uniswapV2Router, tokenAmount);

        IUniswapV2Router02(uniswapV2Router)
            .addLiquidityETH
            .value(ethAmount)(
                tokenAddress,
                tokenAmount,
                0,
                0,
                address(this),
                block.timestamp
            );
     }

    // returns token amount
    function fogDensity() external view returns (uint256) {
        return balanceOf(address(this));
    }
    
    function ERC20LpSupply() external view returns (uint256) {
        return IUniswapV2ERC20(tokenAddressPair).balanceOf(address(this));
     }

    // returns token amount
    function lockedSupply() external view returns (uint256) {
        uint256 lpTotalSupply = ERC20(uniswapV2Pair).totalSupply();
        uint256 lpBalance = lockedLiquidity();
        uint256 percentOfLpTotalSupply = lpBalance.mul(1e12).div(lpTotalSupply);

        uint256 uniswapBalance = balanceOf(uniswapV2Pair);
        uint256 _lockedSupply = uniswapBalance.mul(percentOfLpTotalSupply).div(1e12);
        return _lockedSupply;
    }

    // returns token amount
    function burnedSupply() external view returns (uint256) {
        uint256 lpTotalSupply = ERC20(uniswapV2Pair).totalSupply();
        uint256 lpBalance = burnedLiquidity();
        uint256 percentOfLpTotalSupply = lpBalance.mul(1e12).div(lpTotalSupply);

        uint256 uniswapBalance = balanceOf(uniswapV2Pair);
        uint256 _burnedSupply = uniswapBalance.mul(percentOfLpTotalSupply).div(1e12);
        return _burnedSupply;
    }

    // returns LP amount, not token amount
    function burnableLiquidity() public view returns (uint256) {
        return ERC20(uniswapV2Pair).balanceOf(address(this));
    }

    // returns LP amount, not token amount
    function burnedLiquidity() public view returns (uint256) {
        return ERC20(uniswapV2Pair).balanceOf(address(0));
    }

    // returns LP amount, not token amount
    function lockedLiquidity() public view returns (uint256) {
        return burnableLiquidity().add(burnedLiquidity());
    }
     /*
        calculates a percentage of tokens to hold as the fee
    */
    function calculateVisabilityFee(
        uint256 _amount,
        uint8 _feeDecimals,
        uint32 _percentage
    ) public pure returns (uint256 locked) {
        locked = _amount.mul(_percentage).div(
            10**(uint256(_feeDecimals) + 2)
        );
    }
}
    
interface IUniswapV2Router02 {
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    
     function swapExactETHForTokensSupportingFeeOnTransferTokens(
         uint amountOutMin,
         address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    
     function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    
}

interface IUniswapV2Pair {
    function sync() external;

}

interface IUniswapV2ERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

} 

interface IWETH {
    
    function deposit() external payable;
}