# Leveraged Synthetic Asset Smart Contract

## Overview

This smart contract is designed to allow users to deposit collateral (in USDC or any specified ERC-20 token) and open leveraged positions in a synthetic asset representing an underlying asset (e.g., ETH/USD). The primary functionalities include depositing and withdrawing collateral, opening and closing leveraged positions, and managing positions by adjusting leverage.

### Key Features

1. **Collateral Management**: Users can deposit and withdraw ERC-20 tokens as collateral.
2. **Leveraged Position Management**: Users can open and close leveraged positions using deposited collateral.
3. **Basic Profit/Loss Calculation**: The contract calculates profit or loss based on a fixed synthetic asset price change upon closing the position.

### Implementation Details

- **Collateral Token**: The contract supports any ERC-20 token as collateral.
- **Leverage**: Users can specify leverage when opening a position, with leverage capped at 10x.
- **Fixed Price**: The synthetic asset's price is assumed to be fixed for simplicity.
- **Security**: The contract implements security best practices to avoid common vulnerabilities.
- **Gas Efficiency**: Efforts have been made to ensure gas efficiency in transactions.

## To Get Started
- `npx hardhat compile` - To compile the smart contracts
- `npx hardhat test` - To Test the workings of Smart Contracts; for gas report run `REPORT_GAS=true npx hardhat test`. I have mentioned all the test cases related to the functioning of smart contracts
- Setup env file based on .env.example file, and run command `npx hardhat run scripts/deploy.ts --network (amoy/sepolia)` to deploy the smart contracts onto the desired testnet

## Deployment on Amoy Testnet

1. Vault - [https://www.oklink.com/amoy/address/0x63deff6834c1a844dbcf8d809666d8b97661d393](https://www.oklink.com/amoy/address/0x63deff6834c1a844dbcf8d809666d8b97661d393)
2. PriceFeed - [https://www.oklink.com/amoy/address/0x38d7593dc1404b7811f28acb63c185e03e0dfab9](https://www.oklink.com/amoy/address/0x38d7593dc1404b7811f28acb63c185e03e0dfab9)
3. WETH - [https://www.oklink.com/amoy/address/0x2484d205c0e4e17d187c6a5992b81eff606fa1d0](https://www.oklink.com/amoy/address/0x2484d205c0e4e17d187c6a5992b81eff606fa1d0)
4. USDC - [https://www.oklink.com/amoy/address/0xa660499c69c984d95c4fc1da035aad7679439413](https://www.oklink.com/amoy/address/0xa660499c69c984d95c4fc1da035aad7679439413)


### Interaction

1. **Deposit Collateral**: Use the `depositCollateral` function to deposit collateral into the contract.
2. **Withdraw Collateral**: Use the `withdrawCollateral` function to withdraw collateral from the contract.
3. **Open Position**: Use the `openPosition` function to open a leveraged position with deposited collateral.
4. **Close Position**: Use the `closePosition` function to close a leveraged position and calculate profit or loss.
5. **Adjust Leverage**: Use the `updatePosition` function to update the leverage of an existing position.

### Assumptions

- The synthetic asset's price is fixed for simplicity and does not reflect real-time market changes.
- Leverage is capped at 10x for risk management purposes.

### Contract Logic

- Users deposit collateral into the contract.
- They can open leveraged positions with deposited collateral, specifying the position size and leverage.
- Profit or loss is calculated based on the difference between the initial synthetic asset price and the closing price.
- Leverage can be adjusted for existing positions.

### Security 
- Included Reentrancy Modifiers to prevent smart contracts from any Reentrancy attacks
- Proper Access control to each function and state variables.
- Used solidity version greater than 0.8, which facilitates underflow/overflow.
- Used the Check-Effects-Interaction Method for each function to maintain the flow and security of Smart Contract
