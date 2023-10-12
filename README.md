# LootBox and Item Contracts

With this project, you can create and manage LootBoxes and Items, which are NFTs (Non-Fungible Tokens). Additionally, a key mechanism is implemented to facilitate unlocking these LootBoxes.

This solution is built using [Hardhat](https://hardhat.org/).

## Deployment Instructions
To deploy the contracts locally, follow these steps:

1. Install the dependencies:
```shell
npm install
```

2. Compile the contracts:
```shell
npx hardhat compile
```

3. Deploy using:
```shell
npx hardhat run scripts/deploy.js
```

## Deploying to Remote Networks
If you wish to deploy the contracts to remote networks, such as mainnet or any testnets, you'll need to update your `hardhat.config.js`.

For demonstration, let's consider deploying to the [Polygon Network](https://polygon.technology/):

Add the following network configuration to `hardhat.config.js`:
```javascript
module.exports = {
  networks: {
    polygon: {
      url: 'https://polygon-rpc.com/',
      accounts: [
        `${PRIVATE_KEY}`,
      ],
    }
  }
};
```

Now, deploy to the specified network:
```shell
npx hardhat run scripts/deploy.js --network polygon
```

## Running Tests
To ensure the robustness of your smart contracts, always test them. Execute tests using:

```shell
npx hardhat test
```

