// JS Libraries
const withData = require('leche').withData;
const { t, NULL_ADDRESS  } = require('../utils/consts');
const Timer = require('../../scripts/utils/Timer');
const { atmToken } = require('../utils/events');

// Smart contracts
const ATMToken = artifacts.require("./ATMToken.sol");

contract('ATMTokenWithdrawVestedTest', function (accounts) {
    let instance;
    const daoAgent = accounts[0];
    const daoMember1 = accounts[2];
    const daoMember2 = accounts[3];
    const timer = new Timer(web3);

    beforeEach('Setup for each test', async () => {
        instance = await ATMToken.new(10000);
    });

    withData({
        _1_claim_vested_basic: [daoMember2, 1000, 7000, 7001, undefined, false],
        _2_claim_vested_before_deadline: [daoMember2, 1000, 7000, 5000, 'VESTING_DEADLINE_NOT_PASSSED', true],
        _3_claim_vested_no_amount: [daoMember1, 1000, 7000, 8000, 'ACCOUNT_DOESNT_HAVE_VESTING', true]
    },function(
        receipent,
        amount,
        vestingPeriod,
        claimTime,
        expectedErrorMessage,
        mustFail
    ) {
        it(t('user', 'withdrawVested', 'Should or should not be able to claim correctly', mustFail), async function() {

        // Setup 
        await instance.mintVesting(daoMember2, amount, vestingPeriod, { from: daoAgent });
            
            try {
                // Invocation
                const currentTime = await timer.getCurrentTimestampInSeconds();
                await timer.advanceBlockAtTime(currentTime + claimTime);
                const result = await instance.withdrawVested({ from: receipent });
                // Assertions
                assert(!mustFail, 'It should have failed because the account is not vested');
                assert(result);
                atmToken
                    .vestingClaimed(result)
                    .emitted(receipent, amount);
            } catch (error) {
                // Assertions
                assert(mustFail);
                assert(error);
                assert.equal(
                    error.reason,
                    expectedErrorMessage
                    );
            }

        });
    });

})