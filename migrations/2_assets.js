const Asset = artifacts.require("Assets")

module.exports = async function (deployer) {
     deployer.deploy(Asset)
}
