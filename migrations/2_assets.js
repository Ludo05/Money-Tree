const MoneyTreeFactory = artifacts.require("MoneyTreeFactory")

module.exports = async function (deployer) {
     await deployer.deploy(MoneyTreeFactory)
}
