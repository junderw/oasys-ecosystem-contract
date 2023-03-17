export const environments = ['production', 'staging', 'yokohama', 'dev'] as const
export type Environments = typeof environments[number]

export type Contracts = 'ExchangeDeposit' | 'ProxyFactory'

export type Code = {
  name: Contracts
  environment: Environments
  address: string
  code: string
  storage: { [slot: string]: string }
}

export const contractAddresses: {
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
    ExchangeDeposit: '0x5200000000000000000000000000000000000030',
    ProxyFactory: '0x5200000000000000000000000000000000000031',
  },
} as const

export const constructorArgs: {
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

export const blockTag = 'latest'
