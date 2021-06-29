import chai, { expect } from 'chai'
import { solidity } from 'ethereum-waffle'
import { Signer } from 'ethers'
import {
  ComputationResult,
  Proof,
  // @ts-ignore
} from 'zokrates-js/node'
import { defaultMaxListeners } from 'events'
import hre from 'hardhat'

import { getMarkets } from '../../config'
import { getPlatformSetting, updatePlatformSetting } from '../../tasks'
import { Market } from '../../types/custom/config-types'
import { ITellerDiamond } from '../../types/typechain'
import { fundedMarket } from '../fixtures'
import {
  LoanType,
  takeOutLoanWithNfts,
  takeOutLoanWithoutNfts,
  outputCraValues,
  fillZKCRAConfigInfo,
  borrowWithZKCRA,
} from '../helpers/loans'

chai.should()
chai.use(solidity)

const { getNamedSigner, evm } = hre

describe('Loans', () => {
  getMarkets(hre.network).forEach(testLoans)

  function testLoans(market: Market): void {
    let deployer: Signer
    let diamond: ITellerDiamond
    // let borrower: Signer

    before(async () => {
      // eslint-disable-next-line
      ({ diamond } = await fundedMarket(hre, {
        assetSym: market.lendingToken,
        amount: 100000,
      }))

      deployer = await getNamedSigner('deployer')
    })
    // tests for merged loan functions
    describe('merge create loan', () => {
      let helpers: any = null
      before(async () => {
        // update percentage submission percentage value to 0 for this test
        const percentageSubmission = {
          name: 'RequiredSubmissionsPercentage',
          value: 0,
        }
        await updatePlatformSetting(percentageSubmission, hre)

        // Advance time
        const { value: rateLimit } = await getPlatformSetting(
          'RequestLoanTermsRateLimit',
          hre
        )
        await evm.advanceTime(rateLimit)
      })
      describe('without NFT', () => {
        it('should create a loan', async () => {
          // get helpers variables after function returns our transaction and
          // helper variables
          const { getHelpers } = await takeOutLoanWithoutNfts(hre, {
            lendToken: market.lendingToken,
            collToken: market.collateralTokens[0],
            loanType: LoanType.UNDER_COLLATERALIZED,
          })
          helpers = await getHelpers()

          // borrower data from our helpers
          // borrower = helpers.details.borrower.signer

          // check if loan exists
          expect(helpers.details.loan).to.exist
        })
        it('should have collateral deposited', async () => {
          // get collateral
          const { collateral } = helpers
          const amount = await collateral.current()

          // check if collateral is > 0
          amount.gt(0).should.eq(true, 'Loan must have collateral')
        })
        it('should be taken out', () => {
          // get loanStatus from helpers and check if it's equal to 2, which means
          // it's active and taken out
          const loanStatus = helpers.details.loan.status
          expect(loanStatus).to.equal(2)
        })

        it('should not be able to take out a loan when loan facet is paused', async () => {
          const LOANS_ID = hre.ethers.utils.id('LOANS')

          // Pause lending
          await diamond
            .connect(deployer)
            .pause(LOANS_ID, true)
            .should.emit(diamond, 'Paused')
            .withArgs(LOANS_ID, await deployer.getAddress())

          // trying to run the function will revert with the same error message
          // written in our PausableMods file
          const { tx } = await takeOutLoanWithoutNfts(hre, {
            lendToken: market.lendingToken,
            collToken: market.collateralTokens[0],
            loanType: LoanType.UNDER_COLLATERALIZED,
          })
          await tx.should.be.revertedWith('Pausable: paused')

          // Unpause lending
          await diamond
            .connect(deployer)
            .pause(LOANS_ID, false)
            .should.emit(diamond, 'UnPaused')
            .withArgs(LOANS_ID, await deployer.getAddress())
        })
        // it('should not be able to take out a loan without enough collateral', async () => {
        //   const { tx } = await takeOutLoanWithoutNfts({
        //     lendToken: market.lendingToken,
        //     collToken: market.collateralTokens[0],
        //     loanType: LoanType.OVER_COLLATERALIZED,
        //     collAmount: 1
        //   })

        //   // Try to take out loan which should fail
        //   await tx.should.be.revertedWith('Teller: more collateral required')
        // })
      })

      describe('with NFT', () => {
        let helpers: any
        before(async () => {
          // Advance time
          const { value: rateLimit } = await getPlatformSetting(
            'RequestLoanTermsRateLimit',
            hre
          )
          await evm.advanceTime(rateLimit)
        })
      })
      it('creates a loan', async () => {
        console.log(helpers.details.loan)
        expect(helpers.details.loan).to.exist
      })
      it('should be an active loan', () => {
        // get loanStatus from helpers and check if it's equal to 2, which means it's active
        const loanStatus = helpers.details.loan.status
        expect(loanStatus).to.equal(2)
      })
    })
    describe('create loan w/ zkCRA', async () => {
      // declare computation and proof variables to be used throughout the test
      let goodScoreComputation: ComputationResult
      let goodProof_: Proof
      let badProof_: Proof
      let helpers: any
      before(async () => {
        // we fill the necessary config information (admins mostly) into our providers
        // and market
        console.log('filling zkCRAConfigInfo')
        await fillZKCRAConfigInfo()
      })
      describe('good score', async () => {
        // check if computation and proof exist
        it('checks if proof are returned from good score', async () => {
          const goodScore = true
          const { proof } = await outputCraValues(goodScore)
          goodProof_ = proof
          goodProof_.should.exist
        })
        it('uses witness, output and proof to take out a loan with a good score', async () => {
          const { getHelpers } = await borrowWithZKCRA({
            proof: goodProof_,
          })
          helpers = await getHelpers()
          // check if loan exists
          expect(helpers.details.loan).to.exist
        })
      })
      describe('bad score', async () => {
        // check if computation and proof exist
        it('checks if proof are returned from bad score', async () => {
          const goodScore = false
          const { proof } = await outputCraValues(goodScore)
          badProof_ = proof
          badProof_.should.exist
        })
        it('take out a loan should fail with bad score', async () => {
          const { tx } = await borrowWithZKCRA({
            proof: badProof_,
          })
          await tx.should.be.revertedWith('market score not high enough!')
        })
      })
    })
  }
})
