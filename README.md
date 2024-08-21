# Legato Movement

TBD

Legato provides a dynamic weight AMM DEX that allows listing tokens with much less capital. Unlike traditional fixed-weight 50/50 AMM DEXs, which requires settlement equivalent to the amount of tokens we want to list. For example, listing 3% of the total supply worth $50K would require another $50K in stablecoin or native tokens to pair. Our system allows for a 90/10 pool setup, saving almost 10 times the capital when listing tokens.

Since dynamic weight DEX requires complex math calculations , we have developed Legato Math, a math library that allows calculation of fractional exponents and nth roots in all fixed-point numbers on Move. It extends from Aptos's fixed-point math library and includes custom code that utilizes the Newton-Raphson method.

## Deployment

The system is live on Movement M1 devnet and fully supporting Aptos's new token standard of fungible asset class. Mock tokens are available for evaluation and USDC can be minted and then used on the DEX to trade for other tokens in the system.

### Movement M1 Devnet

Component Name | Address / ID
--- | --- 
Package |  0xa354aea25485832cae78f9fa6593094af9d0b9f17f2a62f68e42ac81c8784d9d

## How to Test

Make sure you have Aptos and/or Movement CLI installed on your machine. 

After that, you can run the following commands to perform end-to-end tests.

```
npm install
npm run test
```
