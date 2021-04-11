// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { MarketStorageLib } from "../../storage/market.sol";

library LibCollateral {
    /**
     * @notice This event is emitted when collateral has been deposited for the loan
     * @param loanID ID of the loan for which collateral was deposited
     * @param borrower Account address of the borrower
     * @param depositAmount Amount of collateral deposited
     */
    event CollateralDeposited(
        uint256 indexed loanID,
        address indexed borrower,
        uint256 depositAmount
    );

    function _payInCollateral(uint256 loanID, uint256 amount) internal {
        require(msg.value == amount, "INCORRECT_ETH_AMOUNT");

        MarketStorageLib.marketStore().totalCollateral += amount;
        MarketStorageLib.marketStore().loans[loanID].collateral += amount;
        MarketStorageLib.marketStore().loans[loanID].lastCollateralIn = block
            .timestamp;
        emit CollateralDeposited(loanID, msg.sender, amount);
    }

    function _payOutCollateral(
        uint256 loanID,
        uint256 amount,
        address payable recipient
    ) internal {
        MarketStorageLib.marketStore().totalCollateral =
            MarketStorageLib.marketStore().totalCollateral -
            (amount);
        MarketStorageLib.marketStore().loans[loanID].collateral =
            MarketStorageLib.marketStore().loans[loanID].collateral -
            (amount);
        recipient.transfer(amount);
    }
}
