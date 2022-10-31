# Start full node
## Download gotabitd binary
```
curl https://github.com/gotabit/gotabit/releases/download/v1.0.0/gotabitd-v1.0.0-linux-amd64.tar.gz | sudo tar -xz -C /usr/bin && sudo mv /usr/bin/build/gotabitd-linux-amd64 /usr/bin/gotabitd
# check binary version
gotabitd version 
```

##  Init new node
gotabitd init <your_moniker> --chain-id gotabit-test-1
```
MONIKER=node004
gotabitd init $MONIKER --chain-id gotabit-test-1
```

## Replace with the testnet genesis.json file
```
curl https://raw.githubusercontent.com/hjcore/networks/master/gotabit-test-1/genesis.json > ~/.gotabit/config/genesis.json
```

## Modify seeds
```
SEEDS=e48d027f0d5806821e16ed9f04f42d01875778c7@34.150.107.33:26656
sed -i "s/^seeds =.*/seeds = \"$SEEDS\"/" ~/.gotabit/config/config.toml
```

## Start new node
```
gotabitd start
```

# Start a validator node
## Add account
```
gotabitd keys add validator --recover
```

## Create validator
```
MONIKER=node004
CHAIN_ID=gotabit-test-1
RPC=https://rcp-testnet.gotabit.dev:443
echo $PASSWORD |  $BIN tx staking create-validator -y \
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
	--from=validator \
	--node $RPC
```
