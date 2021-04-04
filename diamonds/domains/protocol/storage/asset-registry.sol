// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract sto_AssetRegistry_v1 {
    struct AssetRegistryLayout {
        mapping(string => address) addresses;
    }

    bytes32 internal constant ASSET_REGISTRY_POSITION =
        keccak256("teller_protocol.storage.asset_settings.v1");

    function getAssetRegistry()
        internal
        pure
        returns (AssetRegistryLayout storage l_)
    {
        bytes32 position = ASSET_REGISTRY_POSITION;

        assembly {
            l_.slot := position
        }
    }
}

abstract contract sto_AssetRegistry is sto_AssetRegistry_v1 {}