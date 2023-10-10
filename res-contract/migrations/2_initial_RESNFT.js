const RESNFT = artifacts.require("RESNFT");

module.exports = function (deployer) {
  deployer.deploy(RESNFT);
};
