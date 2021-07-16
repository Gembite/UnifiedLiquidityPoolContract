const GBTS = artifacts.require("GBTS");
const ULP = artifacts.require("UnifiedLiquidityPool");
const RNG = artifacts.require("RandomNumberConsumer");
const { assert } = require("chai");
const { BN } = require("web3-utils");

contract("ULP", (accounts) => {
    let gbts_contract, ulp_contract, rng_contract;

    before(async () => {
        await GBTS.new(
            { from: accounts[0] }
        ).then((instance) => {
            gbts_contract = instance;
        });

        await RNG.new(
            "0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9",   // Chainlink VRF Coordinator address
            "0xa36085F69e2889c224210F603D836748e7dC0088",   // LINK token address
            "0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4",   // Key Hash
            1, // fee
            { from: accounts[0] }
        ).then((instance) => {
            rng_contract = instance;
        });

        await ULP.new(
            gbts_contract.address,
            rng_contract.address,
            { from: accounts[0] }
        ).then((instance) => {
            ulp_contract = instance;
        });
    });

    describe("Start Staking", () => {
        it("Start staking is not working with insuffcient balance", async () => {
            let thrownError;
            try {
                await ulp_contract.startStaking(
                    new BN('100000000000000000000000000000000'),
                    { from: accounts[0] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'ULP: Caller has not enough balance',
            )
        });

        it("Staking is not working without initial staking", async () => {
            let thrownError;
            try {
                await ulp_contract.stake(
                    new BN('1000000000000000000000'), //1000 GBTS
                    { from: accounts[0] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'ULP: Owner must initialize staking',
            )
        });

        it("Exit Staking is not working without initial staking", async () => {
            let thrownError;
            try {
                await ulp_contract.exitStake(
                    new BN('1000000000000000000000'), //1000 GBTS
                    { from: accounts[0] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'ULP: Owner must initialize staking',
            )
        });

        it("Start staking is working", async () => {
            await gbts_contract.approve(ulp_contract.address, new BN('1000000000000000000000'), { from: accounts[0] });

            await ulp_contract.startStaking(
                new BN('1000000000000000000000'), //1000 GBTS
                { from: accounts[0] }
            );

            assert.equal(new BN(await ulp_contract.balanceOf(ulp_contract.address)).toString(), new BN('1000000000000000000000').toString());
            assert.equal(new BN(await gbts_contract.balanceOf(ulp_contract.address)).toString(), new BN('1000000000000000000000').toString());
        });

        it("Start staking can't do again.", async () => {
            await gbts_contract.approve(ulp_contract.address, new BN('1000000000000000000000'), { from: accounts[0] });
            let thrownError;
            try {
                await ulp_contract.startStaking(
                    new BN('1000000000000000000000'), //1000 GBTS
                    { from: accounts[0] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                "ULP: FAIL",
            )
        });

    });

    describe("Staking", () => {
        it("Staking is not working with insuffcient balance", async () => {
            let thrownError;
            try {
                await ulp_contract.stake(
                    new BN('1000000000000000000000'), //1000 GBTS
                    { from: accounts[1] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'ULP: Caller has not enough balance',
            )
        });

        it("Staking is working", async () => {
            await gbts_contract.transfer(accounts[1], new BN('2000000000000000000000'), { from: accounts[0] });
            await gbts_contract.approve(ulp_contract.address, new BN('1000000000000000000000'), { from: accounts[1] });

            await ulp_contract.stake(
                new BN('1000000000000000000000'), //1000 GBTS
                { from: accounts[1] }
            );

            assert.equal(new BN(await ulp_contract.balanceOf(accounts[1])).toString(), new BN('970000000000000000000').toString());
            assert.equal(new BN(await gbts_contract.balanceOf(ulp_contract.address)).toString(), new BN('2000000000000000000000').toString());
        });
    });

    describe("Exit Staking", () => {
        it("Exit staking is not working with insuffcient balance", async () => {
            let thrownError;
            try {
                await ulp_contract.exitStake(
                    new BN('100000000000000000000000'), //100000 GBTS
                    { from: accounts[2] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'ULP: Caller has not enough balance',
            )
        });

        it("Exit Staking is working", async () => {

            await ulp_contract.exitStake(
                new BN('100000000000000000000'), //100 GBTS
                { from: accounts[1] }
            );

            assert.equal(new BN(await gbts_contract.balanceOf(accounts[1])).toString(), new BN('1098477157360406091370').toString());
            assert.equal(new BN(await gbts_contract.balanceOf(ulp_contract.address)).toString(), new BN('1901522842639593908630').toString());
        });
    });

    describe("Add To DividendPool", () => {
        it("Adding DividendPool is not working with insuffcient balance", async () => {
            let thrownError;
            try {
                await ulp_contract.addToDividendPool(
                    new BN('10000000000000000000000000'), //1000000000 GBTS
                    { from: accounts[1] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'ULP: Caller has not enough balance',
            )
        });

        it("Adding DividendPool is working", async () => {

            await gbts_contract.transfer(accounts[2], new BN('100000000000000000000000'), { from: accounts[0] }); // 100000 GBTS
            await gbts_contract.transfer(accounts[3], new BN('200000000000000000000000'), { from: accounts[0] }); // 200000 GBTS
            await gbts_contract.transfer(accounts[4], new BN('300000000000000000000000'), { from: accounts[0] }); // 300000 GBTS
            await gbts_contract.transfer(accounts[5], new BN('400000000000000000000000'), { from: accounts[0] }); // 400000 GBTS

            await gbts_contract.approve(ulp_contract.address, new BN('10000000000000000000000'), { from: accounts[2] });
            await gbts_contract.approve(ulp_contract.address, new BN('20000000000000000000000'), { from: accounts[3] });
            await gbts_contract.approve(ulp_contract.address, new BN('30000000000000000000000'), { from: accounts[4] });
            await gbts_contract.approve(ulp_contract.address, new BN('40000000000000000000000'), { from: accounts[5] });

            await ulp_contract.stake(
                new BN('10000000000000000000000'),
                { from: accounts[2] }
            );
            await ulp_contract.stake(
                new BN('20000000000000000000000'),
                { from: accounts[3] }
            );
            await ulp_contract.stake(
                new BN('30000000000000000000000'),
                { from: accounts[4] }
            );
            await ulp_contract.stake(
                new BN('40000000000000000000000'),
                { from: accounts[5] }
            );

            await ulp_contract.addToDividendPool(
                new BN('1000000000000000000000'), //1000 sGBTS
                { from: accounts[2] }
            );

            await ulp_contract.addToDividendPool(
                new BN('2000000000000000000000'), //2000 sGBTS
                { from: accounts[3] }
            );

            await ulp_contract.addToDividendPool(
                new BN('3000000000000000000000'), //3000 sGBTS
                { from: accounts[4] }
            );

            await ulp_contract.addToDividendPool(
                new BN('4000000000000000000000'), //4000 sGBTS
                { from: accounts[5] }
            );

            assert.equal(new BN(await ulp_contract.balanceOf(accounts[2])).toString(), new BN('8539196476241324079014').toString());
            assert.equal(new BN(await ulp_contract.balanceOf(accounts[3])).toString(), new BN('16597486604495049204629').toString());
            assert.equal(new BN(await ulp_contract.balanceOf(accounts[4])).toString(), new BN('24371560973958152805769').toString());
            assert.equal(new BN(await ulp_contract.balanceOf(accounts[5])).toString(), new BN('31964799686456552869058').toString());
        });
    });

    describe("Get balance of user in dividendPool", () => {
        it("Getting balance of user is not working", async () => {
            let thrownError;
            try {
                await ulp_contract.getBalanceofUserHoldInDividendPool(
                    { from: accounts[6] }
                );
            } catch (error) {
                thrownError = error;
            }
            assert.include(
                thrownError.message,
                'ULP: Caller is not in dividend pool.',
            )
        });

        it("Getting balance of user is working", async () => {
            assert.equal(new BN(await ulp_contract.getBalanceofUserHoldInDividendPool({ from: accounts[2] })).toString(), new BN('1000000000000000000000').toString());
            assert.equal(new BN(await ulp_contract.getBalanceofUserHoldInDividendPool({ from: accounts[3] })).toString(), new BN('2000000000000000000000').toString());
            assert.equal(new BN(await ulp_contract.getBalanceofUserHoldInDividendPool({ from: accounts[4] })).toString(), new BN('3000000000000000000000').toString());
            assert.equal(new BN(await ulp_contract.getBalanceofUserHoldInDividendPool({ from: accounts[5] })).toString(), new BN('4000000000000000000000').toString());
        });

        it("Check again adding to DividendPool", async () => {
            await ulp_contract.addToDividendPool(
                new BN('1000000000000000000000'), //1000 sGBTS
                { from: accounts[2] }
            );
            assert.equal(new BN(await ulp_contract.balanceOf(accounts[2])).toString(), new BN('7539196476241324079014').toString());
            assert.equal(new BN(await ulp_contract.getBalanceofUserHoldInDividendPool({ from: accounts[2] })).toString(), new BN('2000000000000000000000').toString());
        });
    });

    describe("Withdraw from the dividend pool", () => {
        it("Withdraw from the dividend pool is not working with insuffcient balance", async () => {
            let thrownError;
            try {
                await ulp_contract.removeFromDividendPool(
                    new BN('4000000000000000000000'), //4000 sGBTS
                    { from: accounts[2] }
                );
            } catch (error) {
                thrownError = error;
            }
            assert.include(
                thrownError.message,
                "ULP: Not enough shares",
            )
        });

        it("Caller is not listed in dividend pool", async () => {
            let thrownError;
            try {
                await ulp_contract.removeFromDividendPool(
                    new BN('4000000000000000000000'), //4000 sGBTS
                    { from: accounts[6] }
                );
            } catch (error) {
                thrownError = error;
            }
            assert.include(
                thrownError.message,
                "ULP: Index out of bounds",
            )
        });

        it("Withdraw from dividend pool is working", async () => {

            await ulp_contract.removeFromDividendPool(
                new BN('1000000000000000000000'), //1000 sGBTS
                { from: accounts[2] }
            );
            assert.equal(new BN(await ulp_contract.getBalanceofUserHoldInDividendPool({ from: accounts[2] })).toString(), new BN('1000000000000000000000').toString());
            assert.equal(new BN(await ulp_contract.balanceOf(accounts[2])).toString(), new BN('8499196476241324079014').toString());
        });
    });

    describe("Distribute", () => {
        it("ULP hasn't got enough GBTS.", async () => {

            await ulp_contract.distribute();
            await ulp_contract.distribute();

            assert.equal(new BN(await gbts_contract.balanceOf(accounts[2])).toString(), new BN('90000000000000000000000').toString());
            assert.equal(new BN(await gbts_contract.balanceOf(accounts[3])).toString(), new BN('180000000000000000000000').toString());
            assert.equal(new BN(await gbts_contract.balanceOf(accounts[4])).toString(), new BN('270000000000000000000000').toString());
            assert.equal(new BN(await gbts_contract.balanceOf(accounts[5])).toString(), new BN('360000000000000000000000').toString());
        });

        it("Remove staker if it hasn't any sGBTS while distribution", async () => {

            await gbts_contract.approve(ulp_contract.address, new BN('50000000000000000000000000'), { from: accounts[0] });

            await ulp_contract.stake(
                new BN('50000000000000000000000000'), // 50 million
                { from: accounts[0] }
            );

            await ulp_contract.removeFromDividendPool(
                new BN('3000000000000000000000'), //1000 sGBTS
                { from: accounts[4] }
            );

            for (var i = 0; i < 6; i++) {
                await ulp_contract.distribute();
            }

            assert.equal(new BN(await gbts_contract.balanceOf(accounts[2])).toString(), new BN('90044943073432772014718').toString());
            assert.equal(new BN(await gbts_contract.balanceOf(accounts[3])).toString(), new BN('180089886146865544029436').toString());
            assert.equal(new BN(await gbts_contract.balanceOf(accounts[4])).toString(), new BN('270000000000000000000000').toString());
            assert.equal(new BN(await gbts_contract.balanceOf(accounts[5])).toString(), new BN('360179772293731088058873').toString());
        });

        it("Distribution is working", async () => {
            for (var i = 0; i < 6; i++) {
                await ulp_contract.distribute();
            }

            assert.equal(new BN(await gbts_contract.balanceOf(accounts[2])).toString(), new BN('90089886146865544029436').toString());
            assert.equal(new BN(await gbts_contract.balanceOf(accounts[3])).toString(), new BN('180269658440596632088308').toString());
            assert.equal(new BN(await gbts_contract.balanceOf(accounts[5])).toString(), new BN('360539316881193264176619').toString());
        });
    });
});
