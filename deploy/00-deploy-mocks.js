const { developmentChains } = require("../helper-hardhat-config")
const BASE_FEE = ethers.utils.parseEther("0.25") // costs 0.25 link per request
const GAS_PRICE_LINK = 1e9 // calculated value base on the gas price of the chain or link per gas
module.exports = async function ({ deployments, getNamedAccounts }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    const args = [BASE_FEE, GAS_PRICE_LINK]

    if (developmentChains.includes(network.name)) {
        log("Local network detected, Deploying mocks")
        // deploy mock VRFCoordinator

        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            args: args,
            log: true,
        })
        log("Mocks deployed")
        log("---------------------------------------------")
    }
}

module.exports.tags = ["all", "mocks"]
