
import { ethers } from "hardhat"

async function main() {
    const deployer = (await ethers.getSigners())[0]
    console.log("Deploying contracts with the account:", deployer.address)
    const PriceFeed = await ethers.getContractFactory("PriceFeed")
    const priceFeed = await PriceFeed.deploy()
    console.log("PriceFeed address:", priceFeed.target)
    const USDC = await ethers.getContractFactory("Token")
    const usdc = await USDC.deploy("USDC", "USDC")
    console.log("USDC address:", usdc.target)
    const WETH = await ethers.getContractFactory("Token")
    const weth = await WETH.deploy("WETH", "WETH")
    console.log("WETH address:", weth.target)
    const Vault = await ethers.getContractFactory("Vault")
    const vault = await Vault.deploy(usdc.target, weth.target, priceFeed.target)
    console.log("Vault address:", vault.target)

}
main().then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });