const TestLink = artifacts.require("TestToken");
const { deployProxy } = require('@openzeppelin/truffle-upgrades');

module.exports = async function (deployer) {
  const saleInstance = await deployProxy(TestLink, ["TestLink", "TL"], { deployer });

  console.log("TestLink deployed at:", saleInstance.address);
};

