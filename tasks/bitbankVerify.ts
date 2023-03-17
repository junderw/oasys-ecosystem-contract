import { readFileSync } from 'fs'
import { task } from 'hardhat/config'

import { Code, Contracts, environments, Environments, blockTag } from './sharedTypes';

type TaskArgs = { input: string }

const logAssert = async (expect: string, actual: string, env: Environments, name: Contracts) => {
  if (actual !== expect) {
    console.error(`Variable mismatch (${env} ${name}), expect: ${expect.slice(0, 66)}, actual: ${actual.slice(0, 66)}`)
  }
}

task('bitbankVerify', 'Verify bitbank codes')
  .addParam('input', 'Input file path')
  .setAction(async ({ input }: TaskArgs, { ethers }) => {
    const expectedCode: Code[] = JSON.parse(readFileSync(input, 'utf8'));
    for (const environment of environments) {
      const expected = expectedCode.filter(v => v.environment === environment);
      const expectedEX = expected.find(v => v.name == "ExchangeDeposit");
      const expectedPF = expected.find(v => v.name == "ProxyFactory");

      if (expected.length !== 2 || expectedEX === undefined || expectedPF === undefined) {
        throw new Error(`Couldn't find environment: ${environment}`);
      }
      const actualEXCode: string = await ethers.provider.send('eth_getCode', [
        expectedEX.address,
        blockTag,
      ]);
      const actualPFCode: string = await ethers.provider.send('eth_getCode', [
        expectedPF.address,
        blockTag,
      ]);
      logAssert(expectedEX.code, actualEXCode, environment, "ExchangeDeposit");
      logAssert(expectedPF.code, actualPFCode, environment, "ProxyFactory");
      const actualEXcold: string = await ethers.provider.send('eth_getStorageAt', [
        expectedEX.address,
        '0x0',
        blockTag,
      ]);
      const actualEXmininput: string = await ethers.provider.send('eth_getStorageAt', [
        expectedEX.address,
        '0x1',
        blockTag,
      ]);
      logAssert(expectedEX.storage['0x00'], actualEXcold, environment, "ExchangeDeposit");
      logAssert(expectedEX.storage['0x01'], actualEXmininput, environment, "ExchangeDeposit");
    }
  });
