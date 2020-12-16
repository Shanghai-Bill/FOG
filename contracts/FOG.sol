/*
  █████  ▒█████    ▄████ 
▓██   ▒ ▒██▒  ██▒ ██▒ ▀█▒
▒████ ░ ▒██░  ██▒ ██░▄▄▄ ░
 ▓█▒  ░▒ ██   ██░░▓█  ██▓
░ █░░   ░ ████▓▒░ ▒▓███▀  ▒
 ▒ ░    ░ ▒░▒░▒░      ░▒  
          ░ ▒ ▒░     ░   ░ 
 ░ ░  ░ ░ ░   ░ ░   ▒  ░ ░ 
  ░ ░ ░  ░        ░   ░ ░       
 ░   ░ ░  ░     ░ ▒ ░ ░░   
     ░   ░ ░ ░ ░ ░░
   ░   ░ ░ ░ ░ ░░  ░  ░                  
    ░ ░   ░ ░     ░ ░            
       ░      ░ 
      ░     ░   ░   ░   

FOG is an experimental, governance branch of the LIQ (LIQUID) token ecosystem.

FOG is a fixed supply token that is acquired by pairing LIQ/ETH LP and staking
the UniV2 LP tokens at https://liquidefi.co/ 

FOG is then emitted to staking LP providers.

The benefits of holding FOG are twofold:

1. FOG LP providers will be rewarded with ETH and FOG from each 
FOG transaction. Initially, these rewards are pooled in the contract. 
At any time, a provider can call the RewardLiquidityProviders command (Condensate)
on the contract, or 'Condensate.exe' on the website, which then automatically 
divides and dispenses rewards to LP holders (this removes any need to stake the FOG LP). 
The reward amount an individual provider receives is based on said LP provider’s share 
of the pool.

How does this work? 

FOG collects a 7.5% fee on all transfers (which can be later adjusted). 
This fee is then split between ***three functions:*** 

- 60% to adding permanently locked FOG LP 
- 30% FOG/ETH sent to the UNIV2 pool. This is then distributed to 
providers based on your pool share percentage after calling the 
RewardLiquidityProviders command (aka Condensate.exe)
- 10% goes to market buying LIQ which is then converted to LIQ/ETH LP. 

2. FOG is the governance token to the LIQ ecosystem.

All rates are adjustable by way of a DAO, controlled by FOG holders / voting.
FOG will have additional governance abilities to be disclosed later as new
strategies reveal themselves to continue to evolve the LIQ ecosystem. 

*/

pragma solidity ^0.5.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "./DoublePoggerino.sol";
import "./Governance.sol";
import "@openzeppelin/contracts/access/roles/SignerRole.sol";

contract FOG is 
    ERC20,
    ERC20Detailed("Fog", "FOG", 18),
    // governance must be before transfer liquidity lock
    // or delegates are not updated correctly
    Governance,
    DoublePoggerino,
    SignerRole
{
    constructor() public {
        // mint tokens which will initially belong to deployer
        // deployer should go seed the pair with some initial liquidity
        _mint(msg.sender, 1000000 * 10**18);
    }
         
        
    function setUniswapV2Router(address _uniswapV2Router) public onlySigner {
        require(uniswapV2Router == address(0), "FogToken::setUniswapV2Router: already set");
        uniswapV2Router = _uniswapV2Router;
    }

    function setUniswapV2Pair(address _uniswapV2Pair) public onlySigner {
        require(uniswapV2Pair == address(0), "FogToken::setUniswapV2Pair: already set");
        uniswapV2Pair = _uniswapV2Pair;
    }
    
    
    function setErc20TokenAddress(address _tokenAddress) public onlySigner {
            tokenAddress = _tokenAddress;
        emit TokenAddressUpdate(tokenAddress);
     }
     
     function setErc20TokenPairAddress(address _tokenAddressPair) public onlySigner {
        tokenAddressPair = _tokenAddressPair;
         emit TokenAddressPairUpdate(tokenAddress); 
     }
     
     function setWethAddress(address _wethAddress) public onlySigner {
         wethAddress = _wethAddress;
         emit WethAddressUpdate(wethAddress); 
     } 

   function updateFees(uint8 _feeDecimals, uint32 _feePercentage)
        public
        onlySigner
    {
        feeDecimals = _feeDecimals;
        feePercentage = _feePercentage;
        emit FeeUpdated(_feeDecimals, _feePercentage);
    }
    
    function updateRewardsSplit(uint32 _fogRewardPercentage)
        public
        onlySigner
    {
        fogRewardPercentage = _fogRewardPercentage;
        emit RewardsUpdate(_fogRewardPercentage);
    }
    
    function updateLpSplits(uint32 _fogLockPercentage, uint32 _tokenLockPercentage) public onlySigner 
    {
        fogLockPercentage = _fogLockPercentage;
        tokenLockPercentage = _tokenLockPercentage;
        emit LocksUpdate(_fogLockPercentage, _tokenLockPercentage);
    }
    
        // this is to remove the token LP that fog contract buys
        // this may or may not be used as future incentives
        // UNABLE TO REMOVE FOG LP due to require
        
    function withdrawForeignTokens(address _tokenContract, address _to) onlySigner public returns (bool) {
        require(_tokenContract != address(this), "cannot withdraw Fog");
        require(_tokenContract != address(uniswapV2Pair), "cannot withdraw FOG LP");
        ERC20 token = ERC20(_tokenContract);
        uint256 amount = token.balanceOf(address(this));
        return token.transfer(_to, amount);
    }

}


   

