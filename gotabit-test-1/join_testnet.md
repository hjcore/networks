# Joining Testnet
General instructions to join the Gotabit Testnet after network genesis. In order to run a Validator, you must create and sync a node, and then upgrade it to a Validator.

## Tetsnet binary version
The correct version of the binary for mainnet at genesis (gotabit-test-1) was v1.0.0

## Recommended Minimum Hardware
The minimum recommended hardware requirements for running a validator for the Gotabit testnet are:
- 2 Cores (modern CPU's)
- 16 GB RAM
- 256 GB

Note that the testnets accumulate data as the blockchain continues. This means that you will need to expand your storage as the blockchain database gets larger with time.

## Download gotabitd binary
```
curl https://github.com/gotabit/gotabit/releases/download/v1.0.0/gotabitd-v1.0.0-linux-amd64.tar.gz | sudo tar -xz -C /usr/bin && \ 
sudo mv /usr/bin/build/gotabitd-linux-amd64 /usr/bin/gotabitd

# check binary version
gotabitd version 
```

## Set your moniker name
Choose your <moniker-name>, this can be any name of your choosing and will identify your validator in the explorer. Set the MONIKER_NAME:
```
# example
MONIKER=node004
```

### Initialize the chain
```
MONIKER=node004
gotabitd init $MONIKER --chain-id gotabit-test-1
```
This will generate the following files in ~/.gotabit/config/
* genesis.json
* node_key.json
* priv_validator_key.json


## Set persistent peer
Persistent peers will be required to tell your node where to connect to other nodes and join the network. To retrieve the peers for the chosen testnet:
```
#Set the base repo URL for the testnet & retrieve peers
CHAIN_REPO='https://raw.githubusercontent.com/hjcore/networks/master/gotabit-test-1' && \
export PEERS="$(curl -s "$CHAIN_REPO/persistent_peers.txt")"
# check it worked
echo $PEERS
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" ~/.gotabit/config/config.toml
```

## Set seeds
```
CHAIN_REPO='https://raw.githubusercontent.com/hjcore/networks/master/gotabit-test-1' && \
export SEEDS="$(curl -s "$CHAIN_REPO/seeds.txt")"
echo $SEEDS
sed -i.bak -e "s/^seeds *=.*/seeds = \"$SEEDS\"/" ~/.gotabit/config/config.toml
```

## Set minimum gas prices
In $HOME/.gotabit/config/app.toml, set gas prices:
```
sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0025ugtb\"/" ~/.gotabit/config/app.toml
```

## Download the genesis file
```
curl https://raw.githubusercontent.com/hjcore/networks/master/gotabit-test-1/genesis.json > ~/.gotabit/config/genesis.json
```
This will replace the genesis file created using gotabitd init command with the genesis file for the testnet.


### Create a local key pair
# Create new keypair
```sh
gotabitd keys add <key-name>

# Restore existing gotabit wallet with mnemonic seed phrase.
# You will be prompted to enter mnemonic seed.
gotabitd keys add <key-name> --recover

# Query the keystore for your public address
gotabitd keys show <key-name> -a
```
Replace <key-name> with a key name of your choosing.


## Get some testnet tokens
Testnet tokens can be requested from the [faucet](https://faucet.gotabit.dev/)

## Syncing the node
After starting the gotabitd daemon, the chain will begin to sync to the network. The time to sync to the network will vary depending on your setup, but could take a very long time. To query the status of your node:
```sh
# start the node
gotabitd start
# check sync
curl http://localhost:26657/status | jq .result.sync_info.catching_up
```
If this command returns true then your node is still catching up. If it returns false then your node has caught up to the network current block and you are safe to proceed to upgrade to a validator node.

## Upgrade to a validator
```
KEY_NAME=validator
MONIKER=node004
CHAIN_ID=gotabit-test-1
RPC=https://rcp-testnet.gotabit.dev:443
gotabitd tx staking create-validator -y \
	--amount=1000000000ugtb \
	--pubkey=$(gotabitd tendermint show-validator) \
	--moniker=$MONIKER \
	--chain-id=$CHAIN_ID \
	--commission-rate="0.10" \
	--commission-max-rate="0.20" \
	--commission-max-change-rate="0.01" \
	--min-self-delegation="1000000000" \
	--gas="auto" \
	--gas-adjustment 1.4 \
	--gas-prices 0.0025ugtb \
	--from=$KEY_NAME \
	--node $RPC
```
## Backup critical files
There are certain files that you need to backup to be able to restore your validator if, for some reason, it damaged or lost in some way. Please make a secure backup of the following files located in ~/.gotabit/config/:
* priv_validator_key.json
* node_key.json
