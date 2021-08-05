const UnifiedLiquidityPool = artifacts.require("UnifiedLiquidityPool");

module.exports = async function (deployer) {

    await deployer.deploy(
        UnifiedLiquidityPool,
        "0xbe9512e2754cb938dd69bbb96c8a09cb28a02d6d", // Deployed GBTS Address
        "0x2B3701955C6d6B4d134F84DA43f480A97829020F", // Deployed RNG Address
    );

    return;
};
