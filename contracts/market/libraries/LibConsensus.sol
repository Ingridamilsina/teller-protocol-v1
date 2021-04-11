// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AppStorageLib } from "../../storage/app.sol";
import {
    MarketStorageLib,
    MarketStorage,
    LoanRequest,
    LoanResponse,
    AccruedLoanTerms,
    Signature
} from "../../storage/market.sol";
import { NumbersLib } from "../../shared/libraries/NumbersLib.sol";
import { NumbersList } from "../../shared/libraries/NumbersList.sol";
import {
    REQUIRED_SUBMISSIONS_PERCENTAGE_SETTING,
    REQUEST_LOAN_TERMS_RATE_LIMIT_SETTING,
    TERMS_EXPIRY_TIME_SETTING,
    MAXIMUM_TOLERANCE_SETTING
} from "../../shared/constants/platform-setting-names.sol";
import { ECDSA } from "./ECDSALib.sol";
import { RolesLib } from "../../contexts2/access-control/roles/RolesLib.sol";
import { SIGNER } from "../../shared/roles.sol";

library LibConsensus {
    using NumbersLib for uint256;
    using NumbersList for NumbersList.Values;

    /**
        @notice Checks if the number of responses is greater or equal to a percentage of
        the number of signers.
     */
    modifier onlyEnoughSubmissions(uint256 responseCount) {
        uint256 percentageRequired =
            AppStorageLib.store().platformSettings[
                REQUIRED_SUBMISSIONS_PERCENTAGE_SETTING
            ]
                .value;

        require(
            responseCount.ratioOf(libStore().signers.array.length) >=
                percentageRequired,
            "INSUFFICIENT_NUMBER_OF_RESPONSES"
        );
        _;
    }

    function libStore() private pure returns (MarketStorage storage) {
        return MarketStorageLib.marketStore();
    }

    function processLoanTerms(
        LoanRequest calldata request,
        LoanResponse[] calldata responses
    )
        external
        returns (
            uint256 interestRate,
            uint256 collateralRatio,
            uint256 maxLoanAmount
        )
    {
        uint256 percentageRequired =
            AppStorageLib.store().platformSettings[
                REQUIRED_SUBMISSIONS_PERCENTAGE_SETTING
            ]
                .value;

        require(
            responses.length.ratioOf(libStore().signers.array.length) >=
                percentageRequired,
            "INSUFFICIENT_NUMBER_OF_RESPONSES"
        );

        address borrower = request.borrower;

        _validateLoanRequest(borrower, request.requestNonce);

        require(
            request.consensusAddress == address(this),
            "BAD_CONSENSUS_ADDRESS"
        );

        uint256 chainId = _getChainId();

        bytes32 requestHash = _hashRequest(request, chainId);

        uint256 responseExpiryLengthValue =
            AppStorageLib.store().platformSettings[TERMS_EXPIRY_TIME_SETTING]
                .value;

        AccruedLoanTerms memory termSubmissions;

        for (uint256 i = 0; i < responses.length; i++) {
            LoanResponse memory response = responses[i];
            _requireAuthorization(SIGNER, response.signer);

            require(
                response.consensusAddress == request.consensusAddress,
                "CONSENSUS_ADDRESS_MISMATCH"
            );

            for (uint8 j = 0; j < i; j++) {
                require(
                    response.signer != responses[j].signer,
                    "SIGNER_ALREADY_SUBMITTED"
                );
            }

            require(
                response.responseTime >=
                    block.timestamp - responseExpiryLengthValue,
                "RESPONSE_EXPIRED"
            );

            bytes32 responseHash =
                _hashResponse(response, requestHash, chainId);

            require(
                _signatureValid(
                    response.signature,
                    responseHash,
                    response.signer
                ),
                "SIGNATURE_INVALID"
            );

            termSubmissions.interestRate.addValue(response.interestRate);
            termSubmissions.collateralRatio.addValue(response.collateralRatio);
            termSubmissions.maxLoanAmount.addValue(response.maxLoanAmount);
        }

        uint256 tolerance =
            AppStorageLib.store().platformSettings[MAXIMUM_TOLERANCE_SETTING]
                .value;

        interestRate = _getConsensus(termSubmissions.interestRate, tolerance);
        collateralRatio = _getConsensus(
            termSubmissions.collateralRatio,
            tolerance
        );
        maxLoanAmount = _getConsensus(termSubmissions.maxLoanAmount, tolerance);
    }

    /**
    Checks if the nonce provided in the request is equal to the borrower's number of loans.
    Also verifies if the borrower has taken out a loan recently (rate limit).
 * @param borrower the borrower's address.
 * @param nonce the nonce included in the loan request.
 */
    function _validateLoanRequest(address borrower, uint256 nonce)
        private
        view
    {
        uint256[] storage borrowerLoans = libStore().borrowerLoans[borrower];
        uint256 numberOfLoans = borrowerLoans.length;

        require(nonce == numberOfLoans, "BAD_NONCE");

        // In case it is the first time that borrower requests loan terms, we don't
        // validate the rate limit.
        if (numberOfLoans == 0) {
            return;
        }

        require(
            libStore().loans[borrowerLoans[numberOfLoans - 1]].loanStartTime +
                AppStorageLib.store().platformSettings[
                    REQUEST_LOAN_TERMS_RATE_LIMIT_SETTING
                ]
                    .value <=
                block.timestamp,
            "REQS_LOAN_TERMS_LMT_EXCEEDS_MAX"
        );
    }

    /**
     * @notice Gets the current chain id using the opcode 'chainid()'.
     * @return the current chain id.
     */
    function _getChainId() private view returns (uint256) {
        // silence state mutability warning without generating bytecode.
        // see https://github.com/ethereum/solidity/issues/2691
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * @notice Generates a hash for the loan request
     * @param request Struct of the protocol loan request
     * @return bytes32 Hash of the loan request
     */
    function _hashRequest(LoanRequest memory request, uint256 chainId)
        private
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    request.borrower,
                    request.recipient,
                    request.consensusAddress,
                    request.requestNonce,
                    request.amount,
                    request.duration,
                    request.requestTime,
                    chainId
                )
            );
    }

    /**
     * @notice Generates a hash for the loan response
     * @param response Structs of the protocol loan responses
     * @param requestHash Hash of the loan request
     * @return bytes32 Hash of the loan response
     */
    function _hashResponse(
        LoanResponse memory response,
        bytes32 requestHash,
        uint256 chainId
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    response.consensusAddress,
                    response.responseTime,
                    response.interestRate,
                    response.collateralRatio,
                    response.maxLoanAmount,
                    chainId,
                    requestHash
                )
            );
    }

    /**
     * @notice It validates whether a signature is valid or not.
     * @param signature signature to validate.
     * @param dataHash used to recover the signer.
     * @param expectedSigner the expected signer address.
     * @return true if the expected signer is equal to the signer. Otherwise it returns false.
     */
    function _signatureValid(
        Signature memory signature,
        bytes32 dataHash,
        address expectedSigner
    ) internal pure returns (bool) {
        return
            expectedSigner ==
            ECDSA.recover(
                keccak256(
                    abi.encodePacked(
                        "\x19Ethereum Signed Message:\n32",
                        dataHash
                    )
                ),
                signature.v,
                signature.r,
                signature.s
            );
    }

    /**
     * @notice Gets the consensus value for a list of values (uint values).
     * @notice The values must be in a maximum tolerance range.
     * @return the consensus value.
     */
    function _getConsensus(NumbersList.Values memory values, uint256 tolerance)
        internal
        pure
        returns (uint256)
    {
        require(values.isWithinTolerance(tolerance), "RESPONSES_TOO_VARIED");

        return values.getAverage();
    }

    function _requireAuthorization(bytes32 role, address account) internal {
        require(RolesLib.hasRole(role, account), "AccessControl: unauthorized");
    }
}
