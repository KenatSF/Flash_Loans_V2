# Aave Flash Loan.

## Dependencies

* Node v14.17.5
* npm 6.14.14
* Ganache CLI v6.12.2
* Truffle v5.1.55 

Packages and their versions are in the "package.json" file

## Resources

* [Aave](https://github.com/aave)
* [Uniswap](https://github.com/Uniswap)
* [Flashbots ](https://github.com/flashbots)

## Testing

The testing is optimized for a successful arbitrage with a Flash Loan. 

Before running the test you should run in a console:

```
ganache-cli --fork EthereumNode-URL@13009534 --unlock 0xE8E8f41Ed29E46f34E206D7D2a7D6f735A3FF2CB 
```
(The block number is important for the testing).

Then, to run the test:

```
truffle test 
```


## Deployment in Polygon

To deploy the contract to the Polygon-Mainnet, run:

```bash
$ truffle migrate --network polygon_mainnet
```
Before deploy it you must change the Aave: Leending Pool Address Provider V2 for its address at Polygon, which is: 0xd05e3E715d945B59290df0ae8eF85c1BdB684744. Also, make sure you have enough MATIC for deployment.
