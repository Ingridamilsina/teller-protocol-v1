import { DeployFunction } from 'hardhat-deploy/types'

import {
  deployLogic,
  DeployLogicArgs,
  deploySettingsProxy,
} from '../utils/deploy-helpers'
import { getTokens } from '../config/tokens'
import { Network } from '../types/custom/config-types'
import { MarketFactory, Settings } from '../types/typechain'
import { ContractTransaction } from 'ethers'

const deployLogicContracts: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments, contracts, ethers, network } = hre
  const { deployer } = await getNamedAccounts()

  const tokens = getTokens(<Network>network.name)

  const mock = network.name.includes('hardhat')
  const logicDeploymentData: Omit<DeployLogicArgs, 'hre'>[] = [
    {
      contract: 'Settings',
    },
    {
      contract: 'AssetSettings',
    },
    {
      contract: 'MarketRegistry',
    },
    {
      contract: 'ChainlinkAggregator',
    },
    {
      contract: 'TToken',
    },
    {
      contract: 'LoanData',
    },
    {
      contract: 'LoanTermsConsensus',
    },
    {
      contract: 'LoanManager',
      mock,
    },
    {
      contract: 'LendingPool',
    },
    {
      contract: 'DappRegistry',
    },
    {
      contract: 'MarketFactory',
    },
    {
      contract: 'Escrow',
    },
    {
      contract: 'Uniswap',
    },
    {
      contract: 'Compound',
    },
    {
      contract: 'Aave',
    },
    {
      contract: 'Yearn',
    },
  ]

  console.log('********** Logic Contracts **********')
  console.log()

  const initialLogicVersions: { logic: string; logicName: string }[] = []
  for (const logicData of logicDeploymentData) {
    const { address: logic } = await deployLogic({
      hre,
      ...logicData,
    })
    initialLogicVersions.push({
      logic,
      logicName: ethers.utils.id(logicData.contract),
    })
  }

  const initDynamicProxyLogic = await deployLogic({
    hre,
    contract: 'InitializeableDynamicProxy',
  })

  console.log()
  console.log('********** Settings **********')
  console.log()

  await deploySettingsProxy({
    hre,
    initialLogicVersions,
  })

  process.stdout.write('   * Initializing Settings...: ')
  const settings = await contracts.get<Settings>('Settings', { from: deployer })
  const isInitialized = (await settings.settings()) === settings.address
  if (!isInitialized) {
    const receipt = await settings['initialize(address,address,address)'](
      tokens.WETH,
      tokens.CETH,
      initDynamicProxyLogic.address
    )
      // Wait for tx to be mined
      .then(({ wait }) => wait())

    process.stdout.write(`with ${receipt.gasUsed} gas \n`)
  } else {
    console.log('Settings already initialized... \n')
  }

  await deployments.save('LogicVersionsRegistry', {
    ...(await deployments.getExtendedArtifact('LogicVersionsRegistry')),
    address: await settings.logicRegistry(),
  })

  await deployments.save('ChainlinkAggregator', {
    ...(await deployments.getExtendedArtifact('ChainlinkAggregator')),
    address: await settings.chainlinkAggregator(),
  })

  await deployments.save('AssetSettings', {
    ...(await deployments.getExtendedArtifact('AssetSettings')),
    address: await settings.assetSettings(),
  })

  await deployments.save('DappRegistry', {
    ...(await deployments.getExtendedArtifact('DappRegistry')),
    address: await settings.dappRegistry(),
  })

  await deployments.save('MarketFactory', {
    ...(await deployments.getExtendedArtifact('MarketFactory')),
    address: await settings.marketFactory(),
  })
  const marketFactory = await contracts.get<MarketFactory>('MarketFactory')

  await deployments.save('MarketRegistry', {
    ...(await deployments.getExtendedArtifact('MarketRegistry')),
    address: await marketFactory.marketRegistry(),
  })

  console.log()
}

deployLogicContracts.tags = ['settings']

export default deployLogicContracts
