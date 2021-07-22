const UnifiedLiquidityPool = artifacts.require("UnifiedLiquidityPool");

module.exports = async function (deployer) {

    await deployer.deploy(
        UnifiedLiquidityPool,
        "0xEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE", // Deployed GBTS Address
        "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", // Deployed RNG Address
    );

    return;
};
