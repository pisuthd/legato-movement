# Legato on Movement

Legato is a comprehensive DeFi solution on Move-based blockchains featuring liquid staking, a dynamic weight DEX, liquidity bootstrapping and options protocols, all of which utilize AI to optimize critical system constants in real-time using external public internet data through LLM RAG fine-tuning, creating a smarter, more resilient DeFi ecosystem for users.

The available services are outlined below:

- Liquid Staking Vaults - Allows staking of native tokens and receiving liquid-form assets on Move-based PoS chains. AI is used to select validators for staking by analyzing factors like credibility and trading volumes.
- Dynamic Weight AMM - An AMM that allows customization of pool weights, ranging from 50/50, 80/20 to 90/10, benefiting projects that want to set up a new pool with much less initial capital paired with their tokens.

Apart from the AI-driven liquid staking system, Legato provides a dynamic weight AMM DEX that enables token listings with significantly less capital. Unlike traditional fixed-weight 50/50 AMM DEXs, which requires settlement equivalent to the amount of tokens we want to list. 

For example, listing 3% of the total supply worth $50K would require another $50K in stablecoin or native tokens to pair. Our system allows for a 90/10 pool setup, saving almost 10 times the capital when listing tokens.

## Deployment

The liquid staking system is live on Movement Suzuka devnet and supporting Aptos's new token standard of fungible asset class.

### Movement Suzuka Devnet

Component Name | Address / ID
--- | --- 
Package |  0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775

## How to Test

Make sure you have Aptos and/or Movement CLI installed on your machine. 

After that, you can run the following commands to perform end-to-end tests.

```
npm install
npm run test
```
