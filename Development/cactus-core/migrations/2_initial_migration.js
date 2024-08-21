const CactusToken = artifacts.require("CactusToken");
const CactusTreasury = artifacts.require("CactusTreasury");
const CactusPrivateSale = artifacts.require("CactusPrivateSale");

module.exports = async function (deployer) {
  await deployer.deploy(CactusToken, '0x1486fCf8817F8Fbf5714180Bec58D8A1Ac19a5BD', 150, 200, 150);
  await deployer.deploy(CactusTreasury, CactusToken.address);
  await deployer.deploy(CactusPrivateSale, CactusToken.address, '0x186506Ce0E71D7E5EC07AD8B023c10F1A401cC5a');
};