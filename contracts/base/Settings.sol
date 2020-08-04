pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

// Libraries
import "@openzeppelin/contracts/lifecycle/Pausable.sol";

// Commons
import "@openzeppelin/contracts/utils/Address.sol";
import "../util/AddressLib.sol";
import "../util/AssetSettingsLib.sol";
import "../util/PlatformSettingsLib.sol";
import "../util/AddressArrayLib.sol";

// Interfaces
import "../interfaces/SettingsInterface.sol";


/**
    @notice This contract manages the configuration of the platform.

    @author develop@teller.finance
 */
contract Settings is Pausable, SettingsInterface {
    using AddressLib for address;
    using Address for address;
    using AssetSettingsLib for AssetSettingsLib.AssetSettings;
    using AddressArrayLib for address[];
    using PlatformSettingsLib for PlatformSettingsLib.PlatformSetting;

    /** Constants */
    /**
        @notice The asset setting name for the maximum loan amount settings.
     */
    bytes32 public constant MAX_LOAN_AMOUNT_ASSET_SETTING = "MaxLoanAmount";
    /**
        @notice The asset setting name for cToken address settings.
     */
    bytes32 public constant CTOKEN_ADDRESS_ASSET_SETTING = "CTokenAddress";

    /* State Variables */

    /**
        @notice It represents a mapping to identify the lending pools paused and not paused.

        i.e.: address(lending pool) => true or false.
     */
    mapping(address => bool) public lendingPoolPaused;

    /**
        @notice Contains minimum version for each node component.

        i.e.: "web2" => "12345" represents "web2" => "01.23.45"
     */
    mapping(bytes32 => uint32) public componentVersions;

    /**
        @notice It represents a mapping to configure the asset settings.
        @notice The key belongs to the asset address. Example: address(DAI) or address(USDC).
        @notice The value has the asset settings.

        Examples:

        address(DAI) => {
            cTokenAddress = 0x1234...890
            maxLoanAmount = 1000 DAI (max)
        }
        address(USDC) => {
            cTokenAddress = 0x2345...901
            maxLoanAmount = 500 USDC (max)
        }
     */
    mapping(address => AssetSettingsLib.AssetSettings) public assetSettings;

    /**
        @notice It contains all the current assets.
     */
    address[] public assets;

    /**
        @notice This mapping represents the platform settings where:

        - The key is the platform setting name.
        - The value is the platform setting. It includes the value, minimum and maximum values.
     */
    mapping(bytes32 => PlatformSettingsLib.PlatformSetting) public platformSettings;

    /** Modifiers */

    /* Constructor */

    /** External Functions */

    /**
        @notice It creates a new platform setting given a setting name, value, min and max values.
        @param settingName setting name to create.
        @param value the initial value for the given setting name.
        @param minValue the min value for the setting.
        @param maxValue the max value for the setting.
     */
    function createPlatformSetting(bytes32 settingName, uint256 value, uint256 minValue, uint256 maxValue)
        external
        onlyPauser()
    {
        require(settingName !=  "", "SETTING_NAME_MUST_BE_PROVIDED");
        platformSettings[settingName].initialize(value, minValue, maxValue);

        emit PlatformSettingCreated(
            settingName,
            msg.sender,
            value,
            minValue,
            maxValue
        );
    }

    /**
        @notice It updates an existent platform setting given a setting name.
        @notice It only allows to update the value (not the min or max values).
        @notice In case you need to update the min or max values, you need to remove it, and create it again.
        @param settingName setting name to update.
        @param newValue the new value to set.
     */
    function updatePlatformSetting(bytes32 settingName, uint256 newValue)
        external
        onlyPauser()
    {
        uint256 oldValue = platformSettings[settingName].update(newValue);

        emit PlatformSettingUpdated(
            settingName,
            msg.sender,
            oldValue,
            newValue
        );
    }

    /**
        @notice Removes a current platform setting given a setting name.
        @param settingName to remove.
     */
    function removePlatformSetting(bytes32 settingName)
        external
        onlyPauser()
    {
        platformSettings[settingName].remove();

        emit PlatformSettingRemoved(
            settingName,
            msg.sender
        );
    }

    /**
        @notice It gets the current platform setting for a given setting name
        @param settingName to get.
        @return the current platform setting.
     */
    function getPlatformSetting(bytes32 settingName)
        external
        view
        returns (PlatformSettingsLib.PlatformSetting memory)
    {
        return _getPlatformSetting(settingName);
    }

    /**
        @notice Add a new Node Component with its version.
        @dev We will allow Node components to be created while the Settings contract is paused,
            as this could be needed to unpause the contract.
        @param componentName name of the component to be added.
        @param minVersion minimum component version supported.
     */
    function createComponentVersion(bytes32 componentName, uint32 minVersion)
        external
        onlyPauser()
    {
        require(minVersion > 0, "INVALID_COMPONENT_VERSION");
        require(componentName != "", "COMPONENT_NAME_MUST_BE_PROVIDED");
        require(componentVersions[componentName] == 0, "COMPONENT_ALREADY_EXISTS");
        componentVersions[componentName] = minVersion;
        emit ComponentVersionCreated(msg.sender, componentName, minVersion);
    }

    /**
        @notice Remove a Node Component from the list.
        @dev We will allow Node components to be removed while the Settings contract is paused,
            as this could be needed to unpause the contract.
        @param componentName name of the component to be removed.
     */
    function removeComponentVersion(bytes32 componentName) external onlyPauser() {
        require(componentName != "", "COMPONENT_NAME_MUST_BE_PROVIDED");
        require(componentVersions[componentName] > 0, "COMPONENT_NOT_FOUND");
        uint32 previousVersion = componentVersions[componentName];
        delete componentVersions[componentName];
        emit ComponentVersionRemoved(msg.sender, componentName, previousVersion);
    }

    /**
        @notice Get the version of a specific node component.
        @param componentName name of the component to return the version.
        @return version of the node component if exists or zero 0 if not found.
     */
    function getComponentVersion(bytes32 componentName) external view returns (uint32) {
        return componentVersions[componentName];
    }

    /**
        @notice Set a new version for a Node Component.
        @dev We will allow Node components to be updated while the Settings contract is paused,
            as this could be needed to unpause the contract.
        @param componentName name of the component to be modified.
        @param newVersion minimum component version supported.
     */
    function updateComponentVersion(bytes32 componentName, uint32 newVersion)
        external
        onlyPauser()
    {
        require(componentName != "", "COMPONENT_NAME_MUST_BE_PROVIDED");
        require(componentVersions[componentName] > 0, "COMPONENT_NOT_FOUND");
        require(
            newVersion > componentVersions[componentName],
            "NEW_VERSION_MUST_INCREASE"
        );
        uint32 oldVersion = componentVersions[componentName];
        componentVersions[componentName] = newVersion;
        emit ComponentVersionUpdated(msg.sender, componentName, oldVersion, newVersion);
    }

    /**
        @notice It gets the current platform setting value for a given setting name
        @param settingName to get.
        @return the current platform setting value.
     */
    function getPlatformSettingValue(bytes32 settingName)
        external
        view
        returns (uint256)
    {
        return _getPlatformSetting(settingName).value;
    }

    /**
        @notice It tests whether a setting name is already configured.
        @param settingName setting name to test.
        @return true if the setting is already configured. Otherwise it returns false.
     */
    function hasPlatformSetting(bytes32 settingName)
        external
        view
        returns (bool)
    {
        return _getPlatformSetting(settingName).exists;
    }

    /**
        @notice It pauses a specific lending pool.
        @param lendingPoolAddress lending pool address to pause.
     */
    function pauseLendingPool(address lendingPoolAddress)
        external
        onlyPauser()
        whenNotPaused()
    {
        lendingPoolAddress.requireNotEmpty("LENDING_POOL_IS_REQUIRED");
        require(!lendingPoolPaused[lendingPoolAddress], "LENDING_POOL_ALREADY_PAUSED");

        lendingPoolPaused[lendingPoolAddress] = true;

        emit LendingPoolPaused(msg.sender, lendingPoolAddress);
    }

    /**
        @notice It unpauses a specific lending pool.
        @param lendingPoolAddress lending pool address to unpause.
     */
    function unpauseLendingPool(address lendingPoolAddress)
        external
        onlyPauser()
        whenNotPaused()
    {
        lendingPoolAddress.requireNotEmpty("LENDING_POOL_IS_REQUIRED");
        require(lendingPoolPaused[lendingPoolAddress], "LENDING_POOL_IS_NOT_PAUSED");

        lendingPoolPaused[lendingPoolAddress] = false;

        emit LendingPoolUnpaused(msg.sender, lendingPoolAddress);
    }

    /**
        @notice It gets whether the platform is paused or not.
        @return true if platform is paused. Otherwise it returns false.
     */
    function isPaused() external view returns (bool) {
        return paused();
    }

    /**
        @notice It creates a new asset settings in the platform.
        @param assetAddress asset address used to create the new setting.
        @param cTokenAddress cToken address used to configure the asset setting.
        @param maxLoanAmount the max loan amount used to configure the asset setting.
     */
    function createAssetSettings(
        address assetAddress,
        address cTokenAddress,
        uint256 maxLoanAmount
    ) external onlyPauser() whenNotPaused() {
        require(assetAddress.isContract(), "ASSET_ADDRESS_MUST_BE_CONTRACT");

        assetSettings[assetAddress].requireNotExists();

        assetSettings[assetAddress].initialize(cTokenAddress, maxLoanAmount);

        assets.add(assetAddress);

        emit AssetSettingsCreated(msg.sender, assetAddress, cTokenAddress, maxLoanAmount);
    }

    /**
        @notice It removes all the asset settings for a specific asset address.
        @param assetAddress asset address used to remove the asset settings.
     */
    function removeAssetSettings(address assetAddress)
        external
        onlyPauser()
        whenNotPaused()
    {
        assetAddress.requireNotEmpty("ASSET_ADDRESS_IS_REQUIRED");
        assetSettings[assetAddress].requireExists();

        delete assetSettings[assetAddress];
        assets.remove(assetAddress);

        emit AssetSettingsRemoved(msg.sender, assetAddress);
    }

    /**
        @notice It updates the maximum loan amount for a specific asset address.
        @param assetAddress asset address to configure.
        @param newMaxLoanAmount the new maximum loan amount to configure.
     */
    function updateMaxLoanAmount(address assetAddress, uint256 newMaxLoanAmount)
        external
        onlyPauser()
        whenNotPaused()
    {
        uint256 oldMaxLoanAmount = assetSettings[assetAddress].maxLoanAmount;

        assetSettings[assetAddress].updateMaxLoanAmount(newMaxLoanAmount);

        emit AssetSettingsUintUpdated(
            MAX_LOAN_AMOUNT_ASSET_SETTING,
            msg.sender,
            assetAddress,
            oldMaxLoanAmount,
            newMaxLoanAmount
        );
    }

    /**
        @notice It updates the cToken address for a specific asset address.
        @param assetAddress asset address to configure.
        @param newCTokenAddress the new cToken address to configure.
     */
    function updateCTokenAddress(address assetAddress, address newCTokenAddress)
        external
        onlyPauser()
        whenNotPaused()
    {
        address oldCTokenAddress = assetSettings[assetAddress].cTokenAddress;

        assetSettings[assetAddress].updateCTokenAddress(newCTokenAddress);

        emit AssetSettingsAddressUpdated(
            CTOKEN_ADDRESS_ASSET_SETTING,
            msg.sender,
            assetAddress,
            oldCTokenAddress,
            newCTokenAddress
        );
    }

    /**
        @notice Tests whether amount exceeds the current maximum loan amount for a specific asset settings.
        @param assetAddress asset address to test the setting.
        @param amount amount to test.
        @return true if amount exceeds current max loan amout. Otherwise it returns false.
     */
    function exceedsMaxLoanAmount(address assetAddress, uint256 amount)
        external
        view
        returns (bool)
    {
        return assetSettings[assetAddress].exceedsMaxLoanAmount(amount);
    }

    /**
        @notice Gets the current asset addresses list.
        @return the asset addresses list.
     */
    function getAssets() external view returns (address[] memory) {
        return assets;
    }

    /**
        @notice Get the current asset settings for a given asset address.
        @param assetAddress asset address used to get the current settings.
        @return the current asset settings.
     */
    function getAssetSettings(address assetAddress)
        external
        view
        returns (AssetSettingsLib.AssetSettings memory)
    {
        return assetSettings[assetAddress];
    }

    /**
        @notice Tests whether an account has the pauser role.
        @param account account to test.
        @return true if account has the pauser role. Otherwise it returns false.
     */
    function hasPauserRole(address account) external view returns (bool) {
        return isPauser(account);
    }

    /** Internal functions */

    /**
        @notice It gets the platform setting for a given setting name.
        @param settingName the setting name to look for.
        @return the current platform setting for the given setting name.
     */
    function _getPlatformSetting(bytes32 settingName)
        internal
        view
        returns (PlatformSettingsLib.PlatformSetting memory)
    {
        return platformSettings[settingName];
    }

    /** Private functions */
}
