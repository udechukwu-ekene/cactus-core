const { expect } = require("chai");
const { expectRevert } = require('@openzeppelin/test-helpers');

const fromWei = (n) => web3.utils.fromWei(n.toString());
const bn2String = (bn) => fromWei(bn.toString());
const toWei = (n) => web3.utils.toWei(n.toString());

const CactusTreasury = artifacts.require("CactusTreasury");
const CactusToken = artifacts.require("CactusToken");

require("chai")
  .use(require("chai-as-promised"))
  .should();

contract("CactusTreasury", (accounts) => {

  let token;
  let treasury;

  before(async () => {
    token = await CactusToken.new(accounts[5], 150, 200, 150);
    treasury = await CactusTreasury.new(token.address);
    await token.updateOperator(treasury.address, true);
    await token.updateOperator(accounts[0], true);
  });

  describe('CactusTreasury', () => {
    it("Check treasutry balance", async function () {
      expect(bn2String(await treasury.balance())).to.equal('0');
    });

    it("Check treasury with funds", async function () {
      await token.transfer(treasury.address, toWei(1000));
      expect(bn2String(await treasury.balance())).to.equal('1000');
    });

    it("Distribute airdrop", async function () {
      await treasury.registerAirdropDistribution();
      await treasury.distributeAirdrop(accounts[1], toWei(500));
      expect(bn2String(await treasury.aidropDistributed())).to.equal('500');
      expect(bn2String(await token.balanceOf(accounts[1]))).to.equal('500');
    });

    it("Mint team funds", async function () {
      await treasury.teamMint(toWei(1000));
      expect(bn2String(await token.balanceOf(accounts[5]))).to.equal('1000');
    });   

    it("initialize reward", async function () {
      const amount = 6e6;
      await token.excludeFromFee(accounts[2]);
      await treasury.initializeReward(accounts[2]);
      expect(bn2String(await token.balanceOf(accounts[2]))).to.equal(amount.toString());
    });    
  });
});
