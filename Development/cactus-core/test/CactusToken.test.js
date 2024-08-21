const { expect } = require("chai");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

const fromWei = (n) => web3.utils.fromWei(n.toString());
const bn2String = (bn) => fromWei(bn.toString());
const toWei = (n) => web3.utils.toWei(n.toString());

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const CactusToken = artifacts.require("CactusToken");
const CactusWhitelist = artifacts.require("CactusWhitelist");

require("chai")
  .use(require("chai-as-promised"))
  .should()

contract("CactusToken", (accounts) => {
  let token;
  const tokencap = 120e6;

  describe('CactusToken', () => {
    before(async () => {
      token = await CactusToken.new(accounts[5], 150, 200, 150);
    });

    it('Check token cap', async () => {
      let cap = await token.cap();
      expect(tokencap.toString()).to.equal(fromWei(cap));
    });

    it('Transfer adds amount to destination account', async () => {
      await token.transfer(accounts[7], toWei(7));
      let balance = await token.balanceOf(accounts[7]);
      expect(fromWei(balance)).to.equal('7');
    });

    it("Check total supply of token", async function () {
      const tokenSupply = await token.totalSupply();
      expect(bn2String(tokenSupply)).to.equal(18e6.toString());
    });

    it("Should set the right owner", async () => {
      expect(await token.owner()).to.equal(accounts[0]);
    });

    it("Transfer token to other adddres", async function () {
      await token.transfer(accounts[2], toWei(2));
      expect(bn2String(await token.balanceOf(accounts[2]))).to.equal('2');
    });

    it("Should mint token", async function () {
      const totalSupply = await token.totalSupply();
      await token.mint(accounts[0], toWei(200));
      expect(bn2String(await token.totalSupply())).to.equal(
        (Number(bn2String(totalSupply)) + 200).toString()
      );
    });

    it("Should burn token", async function () {
      const totalSupply = await token.totalSupply();
      await token.burn(accounts[0], toWei(200));
      expect(bn2String(await token.totalSupply())).to.equal(
        (Number(bn2String(totalSupply)) - 200).toString()
      );
    });

    it("Liquidity ownership transfer", async function () {
      await token.transfer(token.address, toWei(2));
      await token.transferLiquidityOwnership(accounts[6]);
      expect(bn2String(await token.balanceOf(token.address))).to.equal('0');
    });
  });

  describe("Whitelist sale", () => {
    before(async () => {
      token = await CactusToken.new(accounts[5], 150, 200, 150);
      whitelist = await CactusWhitelist.new(token.address);
      await token.excludeFromFee(whitelist.address);
      await token.updateOperator(whitelist.address, true);
    });

    it("Register whitelist", async function () {
      await whitelist.setWhitelistStatus(true);
      await whitelist.registerWhitelist(accounts[2], { from: accounts[2], value: toWei(10), gas: 3000000 });
      expect(bn2String(await token.balanceOf(accounts[2]))).to.equal('0');
    });

    it("Release initial payment", async function () {
      console.log(await whitelist.holderInfo(accounts[2]));
      await whitelist.initialPaymentRelease();
      expect(bn2String(await token.balanceOf(accounts[2]))).to.equal('48000');
    });
  });
});