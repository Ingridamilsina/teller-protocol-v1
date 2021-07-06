// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IDiamondCut } from "./IDiamondCut.sol";
import { IDiamondLoupe } from "./IDiamondLoupe.sol";

import { SettingsFacet } from "../../settings/SettingsFacet.sol";
import { PlatformSettingsFacet } from "../../settings/platform/PlatformSettingsFacet.sol";
import { AssetSettingsDataFacet } from "../../settings/asset/AssetSettingsDataFacet.sol";
import { AssetSettingsFacet } from "../../settings/asset/AssetSettingsFacet.sol";
import { PausableFacet } from "../../settings/pausable/PausableFacet.sol";
import { LendingFacet } from "../../lending/LendingFacet.sol";
import { CreateLoanFacet } from "../../market/CreateLoanFacet.sol";
import { LoanDataFacet } from "../../market/LoanDataFacet.sol";
import { RepayFacet } from "../../market/RepayFacet.sol";
import { SignersFacet } from "../../market/SignersFacet.sol";
import { NFTFacet } from "../../nft/NFTFacet.sol";
import { CollateralFacet } from "../../market/CollateralFacet.sol";
import { CompoundFacet } from "../../escrow/dapps/CompoundFacet.sol";
import { UniswapFacet } from "../../escrow/dapps/swappers/UniswapFacet.sol";
import { AaveFacet } from "../../escrow/dapps/AaveFacet.sol";
import { SushiswapFacet } from "../../escrow/dapps/swappers/SushiswapFacet.sol";
import { PoolTogetherFacet } from "../../escrow/dapps/PoolTogetherFacet.sol";

abstract contract ITellerDiamond is
    SettingsFacet,
    PlatformSettingsFacet,
    AssetSettingsDataFacet,
    AssetSettingsFacet,
    PausableFacet,
    LendingFacet,
    CollateralFacet,
    CreateLoanFacet,
    LoanDataFacet,
    RepayFacet,
    SignersFacet,
    NFTFacet,
    CompoundFacet,
    //    UniswapFacet,
    AaveFacet,
    //    SushiswapFacet,
    PoolTogetherFacet,
    IDiamondCut,
    IDiamondLoupe
{}
