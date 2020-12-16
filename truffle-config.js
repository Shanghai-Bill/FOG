
require('dotenv').config();
const HDWalletProvider = require('@truffle/hdwallet-provider');
const PRIV_KEY = process.env.PRIV_KEY;
const INFURA_API_KEY = process.env.INFURA_API_KEY;

module.exports = {

  networks: {
    
    mainnet: {
      provider: () => new HDWalletProvider(
        process.env.PRIV_KEY, 
        process.env.INFURA_API_KEY),

      network_id: 1,       
      gas: 8000000,
      gasPrice: 60000000000,
      confirmations: 2,
      skipDryRun: true,    

      }
    },


  compilers: {
    solc: {
      version: "0.5.17",          
      settings: {          
      optimizer: {
        enabled: true,
        runs: 10000
      },
    }
  }
}
};
