import { writeFileSync } from 'fs'
import { task } from 'hardhat/config'

import { blockTag, Code, constructorArgs, contractAddresses, Environments } from './sharedTypes';

type TaskArgs = { output: string }

const assertVariable = async (method: () => Promise<string>, expect: string) => {
  const actual = await method()
  if (actual !== expect) {
    throw new Error(`Variable mismatch, expect: ${expect}, actual: ${actual}`)
  }
}

task('bitbank', 'Create bitbank codes')
  .addParam('output', 'Output file path')
  .setAction(async ({ output }: TaskArgs, { ethers }) => {
    const exchangeDepositFactory = await ethers.getContractFactory('ExchangeDeposit')
    const proxyFactoryFactory = await ethers.getContractFactory('ProxyFactory')
    const dumps: Code[] = []

    for (const [key, addrs] of Object.entries(contractAddresses)) {
      const environment = key as Environments
      const args = constructorArgs[environment]

      // deploy contracts
      const deployedExchangeDeposit = await exchangeDepositFactory.deploy(
        args.coldAddr,
        args.adminAddr,
        addrs.ExchangeDeposit,
      )
      const deployedProxyFactory = await proxyFactoryFactory.deploy(addrs.ExchangeDeposit)

      // assert contract variables
      await assertVariable(deployedExchangeDeposit.coldAddress, args.coldAddr)
      await assertVariable(deployedExchangeDeposit.adminAddress, args.adminAddr)
      await assertVariable(deployedExchangeDeposit.thisAddress, addrs.ExchangeDeposit)
      await assertVariable(deployedProxyFactory.mainAddress, addrs.ExchangeDeposit)

      // get contract code
      dumps.push({
        name: 'ExchangeDeposit',
        environment,
        address: addrs.ExchangeDeposit,
        code: await ethers.provider.send('eth_getCode', [
          deployedExchangeDeposit.address,
          blockTag,
        ]),
        storage: {
          // address payable public coldAddress
          '0x00': await ethers.provider.send('eth_getStorageAt', [
            deployedExchangeDeposit.address,
            '0x0',
            blockTag,
          ]),
          // uint256 public minimumInput
          '0x01': await ethers.provider.send('eth_getStorageAt', [
            deployedExchangeDeposit.address,
            '0x1',
            blockTag,
          ]),
        },
      })
      dumps.push({
        name: 'ProxyFactory',
        environment,
        address: addrs.ProxyFactory,
        code: await ethers.provider.send('eth_getCode', [deployedProxyFactory.address, blockTag]),
        storage: {},
      })
    }

    writeFileSync(output, JSON.stringify(dumps, null, 2))
  })
