const assert = require('assert');
const DeployerApp = require('./utils/DeployerApp');
const PoolDeployer = require('./utils/PoolDeployer');
const initSettings = require('./utils/init_settings');

const ERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol");

// Official Smart Contracts
const ZDAI = artifacts.require("./base/ZDAI.sol");
const ZUSDC = artifacts.require("./base/ZUSDC.sol");
const Settings = artifacts.require("./base/Settings.sol");
const MarketsState = artifacts.require("./base/MarketsState.sol");
const Lenders = artifacts.require("./base/Lenders.sol");
const EtherCollateralLoans = artifacts.require("./base/EtherCollateralLoans.sol");
const TokenCollateralLoans = artifacts.require("./base/TokenCollateralLoans.sol");
const LendingPool = artifacts.require("./base/LendingPool.sol");
const InterestConsensus = artifacts.require("./base/InterestConsensus.sol");
const LoanTermsConsensus = artifacts.require("./base/LoanTermsConsensus.sol");
const ChainlinkPairAggregator = artifacts.require("./providers/chainlink/ChainlinkPairAggregator.sol");
const InverseChainlinkPairAggregator = artifacts.require("./providers/chainlink/InverseChainlinkPairAggregator.sol");

const tokensRequired = ['DAI', 'USDC', 'LINK'];
const chainlinkOraclesRequired = ['DAI_ETH', 'USDC_ETH', 'LINK_USD'];

module.exports = async function(deployer, network, accounts) {
  console.log(`Deploying smart contracts to '${network}'.`)
  // Getting network configuration.
  const appConfig = require('../config')(network);
  const { networkConfig, env } = appConfig;

  // Getting configuration values.
  const deployerAccountIndex = env.getDefaultAddressIndex().getOrDefault();
  const deployerAccount = accounts[deployerAccountIndex];
  console.log(`Deployer account index is ${deployerAccountIndex} => ${deployerAccount}`);
  const { maxGasLimit, tokens, chainlink, compound } = networkConfig;
  assert(maxGasLimit, `Max gas limit for network ${network} is undefined.`);

  // Validations
  tokensRequired.forEach( tokenName => assert(tokens[tokenName], `${tokenName} token address is not defined.`));
  chainlinkOraclesRequired.forEach( pairName => assert(chainlink[pairName], `Chainlink: ${pairName} oracle address is undefined.`));

  const txConfig = { gas: maxGasLimit, from: deployerAccount };

  // Creating DeployerApp helper.
  const deployerApp = new DeployerApp(deployer, web3, deployerAccount, network);
  const currentBlockNumber = await web3.eth.getBlockNumber();

  await deployerApp.deploys([ZDAI, ZUSDC], txConfig);
  console.log(`Deployed tokens: ZDAI [${ZDAI.address}] ZUSDC [${ZUSDC.address}] `);  
  
  await deployerApp.deploy(MarketsState, txConfig);
  await deployerApp.deploy(Settings, txConfig);
  const settingsInstance = await Settings.deployed();
  await initSettings(
    settingsInstance,
    { ...networkConfig, txConfig, network, currentBlockNumber, web3 },
    { ERC20 },
  );

  const aggregators = {};
  
  for (const chainlinkOraclePair of chainlinkOraclesRequired) {
    const chainlinkOracleInfo = chainlink[chainlinkOraclePair];
    const {
      address,
      collateralDecimals,
      responseDecimals,
      inversed,
    } = chainlinkOracleInfo;

    const ChainlinkPairAggregatorReference = inversed ? InverseChainlinkPairAggregator : ChainlinkPairAggregator;
    let chainlinkPairAggregatorName =  `ChainlinkPairAggregator_${chainlinkOraclePair.toUpperCase()}`;
    if(inversed) {
      const pairs = chainlinkOraclePair.split('_');
      chainlinkPairAggregatorName =  `ChainlinkPairAggregator_${pairs[1].toUpperCase()}_${pairs[0]}`;
    }
    await deployerApp.deployWith(
      chainlinkPairAggregatorName,
      ChainlinkPairAggregatorReference,
      address,
      responseDecimals,
      collateralDecimals,
      txConfig
    );
    console.log(`New aggregator (Inversed? ${inversed}) for ${chainlinkOraclePair} (Collateral Decimals: ${collateralDecimals} / Response Decimals: ${responseDecimals}): ${ChainlinkPairAggregator.address} (using Chainlink Oracle address ${address})`);
    aggregators[chainlinkOraclePair] = ChainlinkPairAggregator.address;
  }

  const deployConfig = {
    tokens,
    aggregators,
    cTokens: compound,
  };

  const artifacts = {
    Lenders,
    LendingPool,
    InterestConsensus,
    LoanTermsConsensus,
    Settings,
  };
  const poolDeployer = new PoolDeployer(deployerApp, deployConfig, artifacts);

  await poolDeployer.deployPool(
    { tokenName: 'DAI', collateralName: 'ETH' },
    {
      Loans: EtherCollateralLoans,
      TToken: ZDAI,
      MarketsState,
    },
    txConfig
  );
  await poolDeployer.deployPool(
    { tokenName: 'USDC', collateralName: 'ETH' },
    {
      Loans: EtherCollateralLoans,
      TToken: ZUSDC,
      MarketsState
    },
    txConfig
  );

  await poolDeployer.deployPool(
    { tokenName: 'DAI', collateralName: 'LINK', aggregatorName: 'LINK_USD' },
    {
      Loans: TokenCollateralLoans,
      TToken: ZDAI,
      MarketsState
    },
    txConfig
  );
  await poolDeployer.deployPool(
    { tokenName: 'USDC', collateralName: 'LINK', aggregatorName: 'LINK_USD' },
    {
      Loans: TokenCollateralLoans,
      TToken: ZUSDC,
      MarketsState
    },
    txConfig
  );

  deployerApp.print();
  deployerApp.writeJson();
  console.log(`${'='.repeat(25)} Deployment process finished. ${'='.repeat(25)}`);
};