const UnifiedLiquidityPool = artifacts.require("UnifiedLiquidityPool");
const GBTS = artifacts.require("GBTS");
const RandomNumberConsumer = artifacts.require("RandomNumberConsumer");

module.exports = async function (deployer) {

    await deployer.deploy(
        GBTS,
    );
    const GBTSInstance = await GBTS.deployed();
    const RNGInstance = await RandomNumberConsumer.deployed();

    await deployer.deploy(
        UnifiedLiquidityPool,
        GBTSInstance.address,
        RNGInstance.address
    );

    return;
};
