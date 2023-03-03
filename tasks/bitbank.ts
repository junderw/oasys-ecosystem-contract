import { writeFileSync } from 'fs'
import { task } from 'hardhat/config'

type TaskArgs = { output: string }

type Environments = 'production' | 'staging' | 'yokohama' | 'dev'

type Contracts = 'ExchangeDeposit' | 'ProxyFactory'

type Code = {
  name: string
  environment: Environments
  address: string
  code: string
  storage: { [slot: string]: string }
}

const contractAddresses: {
  [environment in Environments]: { [contract in Contracts]: string }
} = {
  production: {
    ExchangeDeposit: '0x5200000000000000000000000000000000000024',
    ProxyFactory: '0x5200000000000000000000000000000000000025',
  },
  staging: {
    ExchangeDeposit: '0x5200000000000000000000000000000000000026',
    ProxyFactory: '0x5200000000000000000000000000000000000027',
  },
  yokohama: {
    ExchangeDeposit: '0x5200000000000000000000000000000000000028',
    ProxyFactory: '0x5200000000000000000000000000000000000029',
  },
  dev: {
    ExchangeDeposit: '0x520000000000000000000000000000000000002A',
    ProxyFactory: '0x520000000000000000000000000000000000002b',
  },
} as const

const constructorArgs: {
  [environment in Environments]: {
    coldAddr: string
    adminAddr: string
  }
} = {
  production: {
    coldAddr: '0x3727cfCBD85390Bb11B3fF421878123AdB866be8',
    adminAddr: '0xE643b5fAd9EFE257d59c17fE19a9BbAC809016b9',
  },
  staging: {
    coldAddr: '0xa3A80B4DAa8be824B73f689eb87Fb0955446DecE',
    adminAddr: '0xd4973C24a370fAce9a53f477f7e369E398865805',
  },
  yokohama: {
    coldAddr: '0x6F83F131b8C3F29F24Fd146C6b75bCE0844dc6d3',
    adminAddr: '0x0434fa25152dBd34A906A192B6cA5B4a8e0030ee',
  },
  dev: {
    coldAddr: '0xBa7b3124bD11C738e22C2eE61F46Cb2108D2356B',
    adminAddr: '0xFB0A2b538bd0C86dB72F3B18cF1CEc634dF2DAdE',
  },
} as const

const assertVariable = async (method: () => Promise<string>, expect: string) => {
  const actual = await method()
  if (actual !== expect) {
    throw new Error(`Variable mismatch, expect: ${expect}, actual: ${actual}`)
  }
}

const blockTag = 'latest'

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
