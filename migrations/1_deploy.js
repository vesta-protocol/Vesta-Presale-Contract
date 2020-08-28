const VTPPresaleDeployer = artifacts.require("VTPPresaleDeployer");
const VTPPresale = artifacts.require("VTPPresale");
const VTPToken = artifacts.require("VTPToken");
const load = require('../utils/fixture')
const cache = require('../utils/cache')

module.exports = function (deployer,network,accounts) {
  deployer.then(async ()=>{
    if (network.indexOf("develop") !== -1){
      let fixture = await load(web3.currentProvider,accounts);
      cache['fixture'] = fixture;
      let step = 2;
      cache['step'] = step
      await deployer.deploy(VTPPresaleDeployer,500,accounts[7],fixture.router.options.address,step,{ "from":accounts[0] });

      let receipt = await VTPPresaleDeployer.deployed()
      let logs = await receipt.getPastEvents("DeployLog", {fromBlock: 0, toBlock: 'latest'})
      console.info(`Token:${logs[0].args.token},Presale:${logs[0].args.presale}`)
    }else if (network === "ropsten") {
      let step = 5
      // await deployer.deploy(VTPPresaleDeployer,500,"0xec9E99d00C96a9C5DBFCD0Ed9D1e6b7729160364","0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",step);
      //Token:0xeF33Bd1d7cca1F5114323DaEB4f373d686E27cBE,Presale:0xD59Ff80B11Db7b06Cb09e3a3B1176b02CAC070C3
      let currency = await web3.eth.getBlockNumber()
      let offset = 100;
      let token = await deployer.deploy(VTPToken)
      let presale = await deployer.deploy(VTPPresale,50000,token.address,'0xec9E99d00C96a9C5DBFCD0Ed9D1e6b7729160364',
          currency + offset,currency + offset + 500,'0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',step);
      await token.transferOwnership(presale.address);
      await presale.transferOwnership(accounts[0]);

      console.info(`Token:${token.address},Presale:${presale.address}`)
    }else if(network === 'mainnet'){
      let step = 100
      // await deployer.deploy(VTPPresaleDeployer,500,"0xec9E99d00C96a9C5DBFCD0Ed9D1e6b7729160364","0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",step);
      //Token:0xeF33Bd1d7cca1F5114323DaEB4f373d686E27cBE,Presale:0xD59Ff80B11Db7b06Cb09e3a3B1176b02CAC070C3
      let currency = await web3.eth.getBlockNumber()
      let startBlock = 10704178;
      let endBlock = 10722178;
      let token = await deployer.deploy(VTPToken,{gas:991667})
      let presale = await deployer.deploy(VTPPresale,50000,token.address,'0x71DAC253dBB63c274519A1b9a6122faff42cBce3', startBlock,endBlock,'0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',step,{gas:2285542});
      //2085542
      await token.transferOwnership(presale.address,{gas:40894});
      // await presale.transferOwnership(accounts[0]);

      //000000000000000000000000000000000000000000000000000000000000c3500000000000000000000000005425c4ebf23d329cb02c14d2131d0ec90784100a00000000000000000000000071dac253dbb63c274519a1b9a6122faff42cbce30000000000000000000000000000000000000000000000000000000000a36f2e0000000000000000000000000000000000000000000000000000000000a3b57e0000000000000000000000007a250d5630b4cf539739df2c5dacb4c659f2488d0000000000000000000000000000000000000000000000000000000000000064
      console.info(`Token:${token.address},Presale:${presale.address}`)
    }
  })
};
