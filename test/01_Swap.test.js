const BN = require('bn.js');
const truffleAssertions = require('truffle-assertions');

const TestToken = artifacts.require('TestToken');
const Swap = artifacts.require('Swap');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const deployToken = async (name, symbol) => {
    const testToken = await deployProxy(TestToken, [name, symbol]);
    return testToken;
};

contract('Swap', (accounts) => {
  let tokenA, tokenB;
  let swap;

  const totalSupply = new BN('800000000000000000000000000', 10);
  const verifiedNode = accounts[1];


  before(async () => {
    console.log("deployer address is ", accounts[0]);

    tokenA = await deployToken(accounts[0], "TestTokenA", "TTA");
    console.log("TestTokenA is deployed at ", tokenA.address);

    tokenB = await deployToken(accounts[0], "TestTokenB", "TTB");
    console.log("TestTokenB is deployed at ", tokenB.address);

    assert.ok(tokenA);
    assert.ok(tokenB);

    swap = await deployProxy(Swap, [tokenA.address, tokenB.address, verifiedNode])

    await tokenA.approve(swap.address, totalSupply, {from: accounts[0]});
    await tokenB.approve(swap.address, totalSupply, {from: accounts[0]});
  });

  it('should put 800 million TestTokenA & TestTokenB in the first account', async () => {
    const balanceA = await tokenA.balanceOf.call(accounts[0]);
    assert(
      balanceA.valueOf().eq(totalSupply),
      "800000000 TTA wasn't in the first account"
    );

    const balanceB = await tokenB.balanceOf.call(accounts[0]);
    assert(
      balanceB.valueOf().eq(totalSupply),
      "800000000 TTB wasn't in the first account"
    );
  });

  it('should add liquidity correctly in the swap contract', async () => {
    const amountA = new BN('1000000000000000000000000');  // 1M
    const rate = await swap.getRate();
    const amountB = (amountA * rate) / (10**8);  // 10M

    await swap.addLiquidity(amountA, amountB);

    const balanceA = await tokenA.balanceOf.call(swap.address);
    assert(
      balanceA.valueOf().eq(amountA),
      "1000000 TTA wasn't in the swap contract"
    );

    const balanceB = await tokenB.balanceOf.call(swap.address);
    assert(
      balanceB.valueOf().eq(amountB),
      "10000000 TTB wasn't in the swap contract"
    );
  });

  it('should swap correctly', async() => {
    const amountA = new BN('1000000000000000000000000', 10);  // 1M
    const amountIn = new BN('1000000000000000000000', 10); // 1K
    const rate = await swap.getRate();
    const amountB = (amountA * rate) / (10**8);  // 10M

    let result = await swap.swap(amountIn, tokenA.address, tokenB.address);

    truffleAssertions.eventEmitted(result, "RequestRate", (event) => {
      return event.txId.eq(new BN(0));
    });

    result = await swap.updateRate(rate, new BN(0));

    truffleAssertions.eventEmitted(result, "SwapCompleted");

    const balanceA = await tokenA.balanceOf.call(swap.address);
    assert(
      balanceA.valueOf().eq(amountA.add(amountIn)),
      "1001000 TTA wasn't in the swap contract"
    );

    const balanceB = await tokenB.balanceOf.call(swap.address);
    assert(
      balanceB.valueOf().eq(amountB.sub(amountIn.mul(new BN(10)))),
      "9990000 TTB wasn't in the swap contract"
    );
  });

  it('should remove liquidity correctly in the swap contract', async () => {
    const amountA = new BN('1001000000000000000000000');  // 1M
    const rate = await swap.getRate();
    const amountB = (amountA * rate) / (10**8);  // 10M

    await swap.removeLiquidity(amountA, amountB);

    const balanceA = await tokenA.balanceOf.call(swap.address);
    assert(
      balanceA.valueOf().eq(new BN(0)),
      "1000000 TTA wasn't in the swap contract"
    );

    const balanceB = await tokenB.balanceOf.call(swap.address);
    assert(
      balanceB.valueOf().eq(new BN(0)),
      "10000000 TTB wasn't in the swap contract"
    );
  });

  it('should get rate and equal as 0', async () => {

    // await swap.requestVolumeData();

    const rate = await swap.getRate();
    console.log("rate = ", rate);
  });

  it('should get rate from the backend', async () => {

    // await swap.requestVolumeData();

    await swap.requestVolumeData();
    // assert(
    //   rate.valueOf().eq(new BN(0)),
    //   "volume is equal with 0"
    // );
    const rate = await swap.getRate();
    console.log(rate);
    // assert(
    //   rate.valueOf().eq(new BN(0)),
    //   "volume is equal with 0"
    // );
  });
});
