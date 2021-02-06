const Web3 = require("web3");

const SuperfluidSDK = require("@superfluid-finance/js-sdk");
//const { web3tx } = require("@decentral.ee/web3-helpers");

const loadContracts = require("./loadContracts");

/**
 * @dev Deploy a Super Token suitable for usage with the POA tokenbridge (ERC-677 compatible)
 * @param isTruffle (optional) Whether the script is used within the truffle framework
 * @param web3Provider (optional) The web3 provider to be used instead
 * @param from (optional) Address to deploy contracts from, use accounts[0] by default
 *
 * Usage: npx truffle exec scripts/deploy-bridged-super-token.js
 */

// TODO: make token name and symbol configurable, register with resolver

module.exports = async function(
    callback,
    argv,
    { isTruffle, web3Provider, from } = {}
) {
    try {
        this.web3 = web3Provider ? new Web3(web3Provider) : web3;
        if (!this.web3) throw new Error("No web3 is available");

        if (!from) {
            const accounts = await this.web3.eth.getAccounts();
            from = accounts[0];
        }

        const { BridgedSuperTokenProxy, BridgedSuperToken } = loadContracts({
            isTruffle,
            web3Provider: this.web3.currentProvider,
            from
        });

        console.log("Deploying Bridged Super Token");

        const chainId = await this.web3.eth.net.getId(); // TODO use eth.getChainId;
        const version = process.env.RELEASE_VERSION || "test";
        console.log("network ID: ", chainId);
        console.log("release version:", version);

        const tokenName = "BridgedSuperToken";
        const tokenSymbol = "BST";

        const sf = new SuperfluidSDK.Framework({
            isTruffle,
            web3Provider: this.web3.currentProvider,
            version,
            from
        });
        await sf.initialize();

        const superTokenFactory = await sf.contracts.ISuperTokenFactory.at(
            await sf.host.getSuperTokenFactory.call()
        );

        // this fails with "TypeError: Cannot read property 'gasUsed' of null"
        /*
        const bstProxy = await web3tx(
            BridgedSuperTokenProxy.new,
            "Create BridgerSuperToken proxy"
        )();

        await web3tx(
            superTokenFactory.initializeCustomSuperToken,
            "initialize custom super token"
        )(bst.address);

        await web3tx(
            bst.initialize,
            "token initialize"
        )("0x0000000000000000000000000000000000000000", 0, tokenName, tokenSymbol);
         */

        console.log("deploying ...");

        const bstProxy = await BridgedSuperTokenProxy.new();

        const bst = await BridgedSuperToken.at(bstProxy.address);

        await superTokenFactory.initializeCustomSuperToken(bst.address, {
            from
        });

        // underlyingToken, underlyingDecimals, name, symbol
        await bst.initialize(
            "0x0000000000000000000000000000000000000000",
            0,
            tokenName,
            tokenSymbol
        );

        console.log(`BridgedSuperToken deployed at ${bst.address}`);

        callback();
    } catch (err) {
        callback(err);
    }
};
