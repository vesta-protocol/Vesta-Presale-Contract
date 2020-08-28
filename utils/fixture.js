const Web3 = require('web3')

const web3_v2 = new Web3()

const {
  BN,           // Big Number support
  constants,    // Common constants, like the zero address and largest integers
  expectEvent,  // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
  ether,
  time,
} = require('@openzeppelin/test-helpers');

function expandTo18Decimals(n) {
  return new BN(`${n}`).mul(new BN(`${10}`).pow(new BN(`${18}`))).toString()
}

const UniswapV2Factory = require('@uniswap/v2-core/build/UniswapV2Factory.json')
const IUniswapV2Pair = require('@uniswap/v2-core/build/IUniswapV2Pair.json')

const ERC20 = require('./build/ERC20.json')
const WETH9 = require('./build/WETH9.json')
const UniswapV2Router02 = require('./build/UniswapV2Router02.json')

/**
 *
 * @param from
 * @param c
 * @param args
 * @returns {Promise<Contract>}
 */
async function deployContract(from, c, args) {
  let {abi, bytecode} = c
  let contract = new web3_v2.eth.Contract(abi);
  return await contract.deploy({
    data:bytecode,
    arguments:args
  }).send({
    from,
    gasPrice: 1000000000,
    gas: 5000000,  //only when connected to ganache
  })
}

// async function deploy(from,contract, bytecode, params) {
//   var contractAddress = '';
//   let data = ''
//   let count = await web3_v2.eth.getTransactionCount(from, "pending")
//   if (params) {
//     data = contract.deploy({
//       data: bytecode,
//       arguments: params
//     }).encodeABI()
//   } else {
//     data = contract.deploy({
//       data: bytecode
//     }).encodeABI()
//   }
//
//   let txObject = {
//     from,
//     gasPrice: 1000000000,
//     gasLimit: 1000000,
//     gas: 3000000,  //only when connected to ganache
//     nonce: web3_v2.utils.toHex(count),
//     data: data,
//   }
//   let signed = await web3_v2.eth.signTransaction(txObject, from)
//   await web3_v2.eth.sendSignedTransaction(signed.raw)
//       .on('error', function (error) {
//         console.log(error)
//       })
//       .on('transactionHash', function (transactionHash) {
//         console.log(transactionHash)
//       })
//       .on("receipt", function (receipt) {
//         contractAddress = receipt.contractAddress
//       })
//   return contractAddress
// }

module.exports = async function v2Fixture(provider,[wallet]) {
  web3_v2.setProvider(provider)
  let option = {
    from:wallet,
    gasPrice: 1000000000,
    gas: 5000000,  //only when connected to ganache
  }
  // deploy tokens
  const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])

  const tokenB = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])
  const WETH = await deployContract(wallet, WETH9)
  const WETHPartner = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])

  // deploy V2
  const factoryV2 = await deployContract(wallet, UniswapV2Factory, [wallet])

  // deploy routers
  const router02 = await deployContract(wallet, UniswapV2Router02, [factoryV2.options.address, WETH.options.address])

  // initialize V2
  await factoryV2.methods.createPair(tokenA.options.address, tokenB.options.address).send(option)
  const pairAddress = await factoryV2.methods.getPair(tokenA.options.address, tokenB.options.address).call({from: wallet})
  // const pair = new Contract(pairAddress, JSON.stringify(IUniswapV2Pair.abi), provider).connect(wallet)
  const pair = new web3_v2.eth.Contract(IUniswapV2Pair.abi, pairAddress)

  const token0Address = await pair.methods.token0().call()
  const token0 = tokenA.options.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.options.address === token0Address ? tokenB : tokenA

  await factoryV2.methods.createPair(WETH.options.address, WETHPartner.options.address).send(option)
  const WETHPairAddress = await factoryV2.methods.getPair(WETH.options.address, WETHPartner.options.address).call({from: wallet})
  const WETHPair = new web3_v2.eth.Contract(IUniswapV2Pair.abi, WETHPairAddress)

  return {
    token0,
    token1,
    WETH,
    WETHPartner,
    factoryV2,
    router02,
    router: router02, // the default router, 01 had a minor bug
    pair,
    WETHPair
  }
}

// module.exports(['0x582a4b0d73477e4d876f6fc01ee32b6410066e42']).then(function (result){
//   console.log(result)
// })
