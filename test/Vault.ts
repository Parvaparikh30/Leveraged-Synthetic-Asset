import { expect } from "chai";
import { AddressLike, ContractRunner, ContractTransactionResponse, Typed } from "ethers";
import hre, { ethers } from "hardhat";
import { Vault } from "../typechain-types";


let owner: any;
let account1: any
let account2: any
let accounts: any
let priceFeed: any
let usdc: any
let weth: any
let vault: any
let price: any


describe("Vault", function () {

    beforeEach(async function () {
        [owner, account1, account2, ...accounts] = await hre.ethers.getSigners();
        const PriceFeed = await hre.ethers.getContractFactory("PriceFeed");
        priceFeed = await PriceFeed.deploy();
        const USDC = await hre.ethers.getContractFactory("Token");
        usdc = await USDC.deploy("USDC", "USDC");
        const WETH = await hre.ethers.getContractFactory("Token");
        weth = await WETH.deploy("WETH", "WETH");
        const Vault = await hre.ethers.getContractFactory("Vault");
        vault = await Vault.deploy(usdc.target, weth.target, priceFeed.target);
        price = await priceFeed.setLatestAnswer(ethers.parseEther("2000"));
        const mintWETHToVault = await weth.mint(vault.target, ethers.parseEther("5000"));
        const mintUSDCToVault = await usdc.mint(vault.target, ethers.parseEther("100000000"));
        const mintUSDCToAccoun1 = await usdc.mint(account1.address, ethers.parseEther("5000"));

    })
    it("Deposit Collateral", async function () {

        const approval = await usdc.connect(account1).approve(vault.target, ethers.parseEther("1000"));
        const allowance = await usdc.allowance(account1.address, vault.target);
        const depositCollateral = await vault.connect(account1).depositCollateral(ethers.parseEther("1000"));
        expect(await vault.connect(account1).collateralAmount(account1)).to.equal(ethers.parseEther("1000"));

    })
    it("Withdraw Collateral", async function () {
        const approval = await usdc.connect(account1).approve(vault.target, ethers.parseEther("1000"));
        const depositCollateral = await vault.connect(account1).depositCollateral(ethers.parseEther("1000"));
        const withdrawCollateral = await vault.connect(account1).withdrawCollateral(ethers.parseEther("500"));
        expect(await vault.connect(account1).collateralAmount(account1)).to.equal(ethers.parseEther("500"));
    })
    it("Open Long Position with leverage of 2", async function () {
        const approval = await usdc.connect(account1).approve(vault.target, ethers.parseEther("1500"));
        const depositCollateral = await vault.connect(account1).depositCollateral(ethers.parseEther("1500"));
        const openPosition = await vault.connect(account1).openPosition(ethers.parseEther("500"), true, 2);
        console.log("position", await vault.connect(account1).getPosition(account1, 1));
        expect(await vault.connect(account1).collateralLocked(account1)).to.equal(ethers.parseEther("500"));
    })
    it("Cancel Position with no price change", async function () {
        const approval = await usdc.connect(account1).approve(vault.target, ethers.parseEther("1500"));
        const depositCollateral = await vault.connect(account1).depositCollateral(ethers.parseEther("1500"));
        const openPosition = await vault.connect(account1).openPosition(ethers.parseEther("500"), true, 2);
        const cancelPosition = await vault.connect(account1).cancelPosition(1);
        expect(await vault.connect(account1).collateralLocked(account1)).to.equal(ethers.parseEther("0"));

    })
    it("Cancel Position with price change to 3000 and Long Position", async function () {
        const approval = await usdc.connect(account1).approve(vault.target, ethers.parseEther("1500"));
        const depositCollateral = await vault.connect(account1).depositCollateral(ethers.parseEther("1500"));
        const openPosition = await vault.connect(account1).openPosition(ethers.parseEther("500"), true, 2);
        const collateralAmountBefore = await vault.connect(account1).collateralAmount(account1);
        console.log("collateralAmountBefore", collateralAmountBefore)
        const setPrice = await priceFeed.setLatestAnswer(ethers.parseEther("3000"));
        const expectedProfit = await vault.connect(account1).expectedPnL(account1.address, 1);
        console.log("expectedProfit", expectedProfit)
        const expectedCollateralAmount = expectedProfit + collateralAmountBefore;
        const cancelPosition = await vault.connect(account1).cancelPosition(1);
        const collateralAmountAfter = await vault.connect(account1).collateralAmount(account1);
        console.log("collateralAmountAfter", await vault.connect(account1).collateralAmount(account1));
        const profit = (collateralAmountAfter - collateralAmountBefore)
        console.log("profit", profit)
        expect(profit).to.equal(expectedProfit[1]);

    })

    it("Cancel Position with price change to 1500 and Long Position", async function () {
        const approval = await usdc.connect(account1).approve(vault.target, ethers.parseEther("1500"));
        const depositCollateral = await vault.connect(account1).depositCollateral(ethers.parseEther("1500"));
        const openPosition = await vault.connect(account1).openPosition(ethers.parseEther("1500"), true, 2);
        const collateralAmountBefore = await vault.connect(account1).collateralAmount(account1);
        console.log("collateralAmountBefore", collateralAmountBefore)
        const setPrice = await priceFeed.setLatestAnswer(ethers.parseEther("1500"));
        let expectedLoss = (await vault.connect(account1).expectedPnL(account1.address, 1))
        console.log("expectedLoss", expectedLoss)
        const cancelPosition = await vault.connect(account1).cancelPosition(1);
        const collateralAmountAfter = await vault.connect(account1).collateralAmount(account1);
        console.log("collateralAmountAfter", await vault.connect(account1).collateralAmount(account1));
        const loss = (collateralAmountBefore - collateralAmountAfter).toString()
        console.log("loss", loss)
        expect(loss).to.equal(expectedLoss[1].toString());
    })

    it("Cancel Position with price change to 2200 and Short Position", async function () {
        const approval = await usdc.connect(account1).approve(vault.target, ethers.parseEther("1500"));
        const depositCollateral = await vault.connect(account1).depositCollateral(ethers.parseEther("1500"));
        const openPosition = await vault.connect(account1).openPosition(ethers.parseEther("1500"), false, 2);
        const collateralAmountBefore = await vault.connect(account1).collateralAmount(account1);
        console.log("collateralAmountBefore", collateralAmountBefore)
        const setPrice = await priceFeed.setLatestAnswer(ethers.parseEther("2200"));
        let expectedLoss = (await vault.connect(account1).expectedPnL(account1.address, 1))
        console.log("expectedLoss", expectedLoss)
        const cancelPosition = await vault.connect(account1).cancelPosition(1);
        const collateralAmountAfter = await vault.connect(account1).collateralAmount(account1);
        console.log("collateralAmountAfter", await vault.connect(account1).collateralAmount(account1));
        const loss = (collateralAmountBefore - collateralAmountAfter).toString()
        console.log("loss", loss)
        expect(loss).to.equal(expectedLoss[1].toString());
    })

    it("Cancel Position with price change to 1500 and Short Position", async function () {

        const approval = await usdc.connect(account1).approve(vault.target, ethers.parseEther("1500"));
        const depositCollateral = await vault.connect(account1).depositCollateral(ethers.parseEther("1500"));
        const openPosition = await vault.connect(account1).openPosition(ethers.parseEther("1500"), false, 2);
        const collateralAmountBefore = await vault.connect(account1).collateralAmount(account1);
        console.log("collateralAmountBefore", collateralAmountBefore)
        const setPrice = await priceFeed.setLatestAnswer(ethers.parseEther("1500"));
        let expectedProfit = (await vault.connect(account1).expectedPnL(account1.address, 1))
        console.log("expectedProfit", expectedProfit)
        const cancelPosition = await vault.connect(account1).cancelPosition(1);
        const collateralAmountAfter = await vault.connect(account1).collateralAmount(account1);
        console.log("collateralAmountAfter", await vault.connect(account1).collateralAmount(account1));
        const profit = (collateralAmountAfter - collateralAmountBefore).toString()
        console.log("profit", profit)
        expect(profit).to.equal(expectedProfit[1].toString());
    })

    it("Update Position by increasing leverage from 2 to 5", async function () {
        const approval = await usdc.connect(account1).approve(vault.target, ethers.parseEther("2000"));
        const depositCollateral = await vault.connect(account1).depositCollateral(ethers.parseEther("2000"));
        const openPosition = await vault.connect(account1).openPosition(ethers.parseEther("2000"), true, 2);
        const updatePosition = await vault.connect(account1).updatePosition(1, 5);
        console.log("position", await vault.connect(account1).getPosition(account1, 1));
        expect(await vault.connect(account1).syntheticAmountLocked()).to.equal(ethers.parseEther("5"));
    })

    it("Invalid Leverage with leverage value equal to 24", async function () {
        const approval = await usdc.connect(account1).approve(vault.target, ethers.parseEther("2000"));
        const depositCollateral = await vault.connect(account1).depositCollateral(ethers.parseEther("2000"));
        await expect(vault.connect(account1).openPosition(ethers.parseEther("2000"), true, 24)).to.be.revertedWith("Leverage Must be less than 10");
    })

})