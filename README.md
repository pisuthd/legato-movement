# Legato AI-Powered DeFi Suite

Legato is a comprehensive DeFi solution on Move-based blockchains featuring liquid staking, a dynamic weight DEX, liquidity bootstrapping and options protocols, all of which utilize AI to optimize critical system constants in real-time using external public internet data through LLM RAG fine-tuning, creating a smarter, more resilient DeFi ecosystem for users.

The available services are outlined below:

- Liquid Staking Vaults - Allows staking of native tokens and receiving liquid-form assets on Move-based PoS chains. AI is used to select validators for staking by analyzing factors like credibility and trading volumes.
- Dynamic Weight AMM - An AMM that allows customization of pool weights, ranging from 50/50, 80/20 to 90/10, benefiting projects that want to set up a new pool with much less initial capital paired with their tokens.

Apart from the AI-driven liquid staking system, Legato provides a dynamic weight AMM DEX that enables token listings with significantly less capital. Unlike traditional fixed-weight 50/50 AMM DEXs, which requires settlement equivalent to the amount of tokens we want to list. 

For example, listing 3% of the total supply worth $50K would require another $50K in stablecoin or native tokens to pair. Our system allows for a 90/10 pool setup, saving almost 10 times the capital when listing tokens.

## Liquid Staking

The Legato Liquid Staking system is live on Suzuka Devnet. Since no staking system is available on the consensus, we have built a mock validator system, which can be found in the smart contract mock_validator.move. The APY is set at a global value, while each validator may have a different commission rate.

```
public entry fun new_pool(validator_address: address, commission_rate_numerator: u128, commission_rate_denominator: u128)
```

In the live system, we have added two validators as follows:
* Validator#1 - 0x1 - Commission Rate 10%
* Validator#2 - 0x2 - Comission Rate 4%

Since it's a mock system, MOVE rewards must be deposited over time. The end-to-end behavior can be checked in the test file.

![Untitled Diagram drawio (8)](https://github.com/user-attachments/assets/6724f852-f937-467a-9ad4-f6da12bb8bc1)

In the vault, users need to stake with MOVE tokens and will receive liquid-staked assets called lvMOVE. lvMOVE is a yield-bearing token that increases in value over time from accrued rewards. For example, 1 lvMOVE received from 1 MOVE staked today can be withdrawn for 1.05 MOVE after one year if the reward rate is set at 5%.

The liquid staking system allows anyone to earn passive income through staking as little as 1 MOVE. For example, on Aptos, the minimum amount to stake is 11 APT, while liquid staking can reduce this to just 1 token. However, all MOVE will be locked in the vault until it reaches a certain amount of 11 MOVE, at which point it will be automatically transferred to the validator assigned by the AI agent.

Users who have lvMOVE can unstake at any time with a 3-day delay. Anyone can evaluate the liquid staking system on https://movement.legato.finance

## AI-Agent

The AI agent is one of the core components of the system, which can be found in the /engine folder. Currently, it needs to be run manually and the results are used to set appropriate values for each DeFi service.

It is made with Node.js and Express. API keys from the following AI services need to be acquired and placed in the environment variable file.

* Claude AI - https://claude.ai - Handles LLM tasks
* Voyage AI - https://www.voyageai.com/ - Text-to-vector conversion

When selecting a validator, the AI collects external data from social posts about each validator and stores it in the database first.

```
Below are the news collected from Twitter feeds for the Cosmostation validator

Cosmostation validator is now live on @agoric
.
Visit @mintscanio and stake $BLD to tap into the benefits of multi-chain liquidity enabled by Agoric orchestration.

Self-custodial Bitcoin staking brought to you by 
@babylonlabs_io
.

Stake $BTC with Cosmostation on the 
@StakingRewards
 staking portal and start earning rewards.
```

Then, using the RAG approach to ask the question against the dataset by providing on-chain data such as staking volume, APY, and commission rates as shown below.

```
Based on the given daily stats, which validator is currently the best to stake with?

Cosmostation

Volume (24h)
$1,877,246.41

Current Staked
$137.5M 

APY
2.96%

Commission Rate
4.00%
```

You can run the command `npm run test-engine` to see the results, which will be similar to the example below.

```
Based on the given criteria and daily stats, the Cosmostation validator appears to be the best option for staking. It has a relatively high daily volume of $1,877,246.41, indicating active participation.

Additionally, it offers a competitive APY of 2.96% with a reasonable commission rate of 4.00%. The P2P validator and KelePool have no daily volume reported, which could be a concern for liquidity and participation.
```

## Deployment

The liquid staking system is live on Movement Suzuka devnet and supporting Aptos's new token standard of fungible asset class.

### Movement Suzuka Devnet

Component Name | Address / ID
--- | --- 
Package |  0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775
lvMOVE | 0x5a9e78e28a018408b72887ac7c2877d38a72d0ea92b3924f1116bc6a4e8be087

## How to Test

Make sure you have Aptos and/or Movement CLI installed on your machine. 

After that, you can run the following commands to perform end-to-end tests on each service.

```
npm install
npm run test-amm
npm run test-vault
npm run test-engine
```
