<div align="center">
  <h1>XPRT ERC20 Placeholder Contract</h1>
  <br/>
</div>

## Additional Feature:
```
1. Added a new method transferToMany which takes addresses and tokens as input and transfers. This method will reduce the gas units
2. It should be noted that when the token is paused, only the owner of the contract can transfer tokens and that only the owner can unpause or pause the token.
```

# 1. Deploying and Testing ERC20 Contract using Remix IDE
## i. Basic Steps:
```
Upload the smart contract in the remix
https://remix.ethereum.org/
```

## ii. Compile 
```
Compile it using compiler 0.7.5+commit.eb77ed08
Check the Optimization check box
```

## iii. Deploy
```
a. Select the type of environment to be injected WEB3 in Remix IDE. It is at the top right corner. It will automatically link to your Metamask plugin account.
b. Make sure that you choose Rinkeby/Goreli test network in your Metamask plugin.
c. Check if the changes you made are reflecting or not. Now click on ‘Deploy Contract’.
d. Once you click on ‘Deploy Contract’, a popup will appear from the Metamask plugin asking for your permission to spend some Ethereum to deploy contract. Press ‘Submit’ to deploy the contract.
e. You can track the deployed contract in your Metamask account contracts tab.
f. By clicking on ‘Contract’ in you contracts tab in the Metamask plugin, you will be redirected to the Ether Scan Website for test network. There you would see the contract deployment information.
g. Click on contract address to view the contract information.
```

## iv. Screenshot on Etherscan
![contract](doc/etherscan.png)

## v. Test
```
On Remix IDE, under deployed contracts, click on arrow and you can test the functions by entering the required params and then click on Transact button.
```

## vi. Instructions for interacting with the contract
```
The token should be paused at first and the transfer should be rejected
a. Try to send any amount of tokens from the deployed account to other address
b. The transaction should be failed because the token is paused by default

Once unpaused the token, it should be able to transfer freely
a. Only token owner can unpause the token.
b. Try to send any amount of tokens between any accounts
c. Should be able to transfer
```

# 2. Deploying ERC20 Contract locally
## i. Pre-requisites:
```
Please install the following:
a. Node.js v8+ LTS and npm (comes with Node)
b. npm install -g truffle
c. openzeppelin-solidity@2.5.1
d. web3

To verify that Truffle is installed properly, type truffle version on a terminal.
```

## ii. Install Meta-mask:
```
MetaMask is a browser extension that serves as a “wallet” that safely stores your cryptocurrencies such as Ether (ETH). It also serves as a “bridge” that connects the web application with the blockchain. You can download and learn more about Metamask at https://metamask.io/.
```

## iii. Initialize the project:
```
Inside the project directory, Run command: truffle init
This will create folders: contracts, migrations, test and truffle-config file
```

## iv. Compile
```
a. Place the smart contract inside contracts folder.
b. Run "truffle compile", this comamnd will create "build" folder which will have the respected .json file of the smart contract
c. In the migrations/directory, create the file 2_deploy_contracts.js and add the following content:
    var MyToken = artifacts.require("MyToken");
    module.exports = function(deployer) {
    deployer.deploy(MyToken);
    };
d. Let’s install all of the modules we’ll need for deploying to Infura.
    npm install --save-dev dotenv truffle-wallet-provider ethereumjs-wallet
```

## v. Edit truffle.js
```
Now edit truffle.js and add the following:

    require('dotenv').config();
    const Web3 = require("web3");
    const web3 = new Web3();
    const WalletProvider = require("truffle-wallet-provider");
    const Wallet = require('ethereumjs-wallet');

    var mainNetPrivateKey = new Buffer(process.env["MAINNET_PRIVATE_KEY"], "hex")
    var mainNetWallet = Wallet.fromPrivateKey(mainNetPrivateKey);
    var mainNetProvider = new WalletProvider(mainNetWallet, "https://mainnet.infura.io/");

    var ropstenPrivateKey = new Buffer(process.env["ROPSTEN_PRIVATE_KEY"], "hex")
    var ropstenWallet = Wallet.fromPrivateKey(ropstenPrivateKey);
    var ropstenProvider = new WalletProvider(ropstenWallet, "https://ropsten.infura.io/");


    module.exports = {
        networks: {
            development: {
            host: "localhost",
            port: 8545,
            network_id: "*" // Match any network id
            },
            ropsten: {
            provider: ropstenProvider,
            // You can get the current gasLimit by running
            // truffle deploy --network rinkeby
            // truffle(rinkeby)> web3.eth.getBlock("pending", (error, result) =>
            //   console.log(result.gasLimit))
            gas: 4600000,
            gasPrice: web3.toWei("20", "gwei"),
            network_id: "3",
            },
            mainnet: {
            provider: mainNetProvider,
            gas: 4600000,
            gasPrice: web3.toWei("20", "gwei"),
            network_id: "1",
            }
        }
    };
```

## vi. Keys
```
1. Click on the fox icon on the top right of your Chrome window.
2. Click on the ellipses that are to the right of "Account 1"
3. Click "Export Private Key"
4. Confirm you password
5. Click the text to copy your private key to you clipboard.

Next open your up “.env” and paste in your private key like so (Your private keys should be the same on both Ropsten and Mainnet):
    ROPSTEN_PRIVATE_KEY="123YourPrivateKeyHere"
    MAINNET_PRIVATE_KEY="123YourPrivateKeyHere"
```

## vii. Deploy
```
$ truffle deploy --network ropsten
    Compiling ./contracts/PersistenceToken.sol...
    Compiling ./contracts/Migrations.sol...
    Compiling zeppelin-solidity/contracts/math/SafeMath.sol...
    Compiling zeppelin-solidity/contracts/token/BasicToken.sol...
    Compiling zeppelin-solidity/contracts/token/ERC20.sol...
    Compiling zeppelin-solidity/contracts/token/ERC20Basic.sol...
    Compiling zeppelin-solidity/contracts/token/StandardToken.sol...
    Writing artifacts to ./build/contracts

    Using network 'ropsten'.

    Running migration: 1_initial_migration.js
    Deploying Migrations...
    ... 0xc2bbe6bf5a7c7c7312c43d65de4c18c51c4d620d5bf51481ea530411dcebc499
    Migrations: 0xd827b6f93fcb50631edc4cf8e293159f0c056538
    Saving successful migration to network...
    ... 0xe6f92402e6ca0b1d615a310751568219f66b9d78b80a37c6d92ca59af26cf475
    Saving artifacts...
    Running migration: 2_deploy_contracts.js
    Deploying PersistenceToken...
    ... 0x02c4d47526772dc524851fc2180b338a6b037500ab298fa2f405f01abdee21c4
    PersistenceToken: 0x973b1a5c753a2d5d3924dfb66028b975e7ccca51
    Saving artifacts...

    The line above “Saving aritfacts” will have be the new address of your contract!
    Copy and paste the address into the Ropsten Etherscan search box and you should see your newly deployed contract!
    You should now be able spend your tokens with any ERC20 compatible wallet like Mist or MyEtherWallet.

    First add your token to Etherface:
        1. Visit http://etherface.io/.
        2. Make sure you've selected "Ropsten" as the network in Metamask
        3. Click "Tokens"
        4. Click the "Plus" icon in the top right
        5. Enter the contract address from above

    Now you’re ready to deploy to mainnet!
        $ truffle deploy --network mainnet
```

## References
```
1. https://www.masonforest.com/blockchain/ethereum/2017/11/13/how-to-deploy-an-erc20-token-in-20-minutes.html
2. https://developers.thundercore.com/docs/erc20-smart-contract/
3. https://www.codementor.io/@unmissable/ultimate-erc-20-token-crowdsale-creation-guide-m8wnb4ke4
4. https://www.evoketechnologies.com/blog/deploying-erc20-tokens-test-network/
```
