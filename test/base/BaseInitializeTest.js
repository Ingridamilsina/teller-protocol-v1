// JS Libraries
const withData = require('leche').withData;
const { t, NULL_ADDRESS } = require('../utils/consts');

// Mock contracts

// Smart contracts
const Base = artifacts.require("./mock/base/BaseMock.sol");

contract('BaseInitializeTest', function (accounts) {

    withData({
        _1_basic: [accounts[0], undefined, false],
        _2_notSettings: [NULL_ADDRESS, 'SETTINGS_MUST_BE_PROVIDED', true],
    }, function(settingsAddress, expectedErrorMessage, mustFail) {
        it(t('user', 'initialize', 'Should (or not) be able to initialize the new instance.', mustFail), async function() {
            // Setup
            const instance = await Base.new();

            try {
                // Invocation
                const result = await instance.externalInitialize(settingsAddress);
                
                // Assertions
                assert(!mustFail, 'It should have failed because data is invalid.');
                assert(result);
            } catch (error) {
                // Assertions
                assert(mustFail);
                assert(error);
                assert.equal(error.reason, expectedErrorMessage);
            }
        });
    });
});