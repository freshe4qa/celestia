#!/bin/bash

while true
do

# Logo

echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '    _                 _                      '
echo -e '   / \   ___ __ _  __| | ___ _ __ ___  _   _ '
echo -e '  / _ \ / __/ _  |/ _  |/ _ \  _   _ \| | | |'
echo -e ' / ___ \ (_| (_| | (_| |  __/ | | | | | |_| |'
echo -e '/_/   \_\___\__ _|\__ _|\___|_| |_| |_|\__  |'
echo -e '                                       |___/ '
echo -e '\e[0m'

sleep 2

# Menu

PS3='Select an action: '
options=(
"Install"
"Create Wallet"
"Create Validator"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install")
echo "============================================================"
echo "Install start"
echo "============================================================"

# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
if [ ! $EVM ]; then
	read -p "Enter ETH address: " EVM
	echo 'export EVM='$EVM >> $HOME/.bash_profile
fi
CELESTIA_PORT=20
if [ ! $WALLET ]; then
	echo "export WALLET=wallet" >> $HOME/.bash_profile
fi
echo "export CELESTIA_CHAIN_ID=mocha" >> $HOME/.bash_profile
echo "export CELESTIA_PORT=${CELESTIA_PORT}" >> $HOME/.bash_profile
source $HOME/.bash_profile

# update
sudo apt update && sudo apt upgrade -y

# packages
sudo apt install curl git jq lz4 build-essential -y

# install go
if ! [ -x "$(command -v go)" ]; then
  ver="1.19.1"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile
fi

# download binary
cd $HOME
rm -rf celestia-app
git clone https://github.com/celestiaorg/celestia-app.git
cd celestia-app
git checkout v0.11.0
make build
mkdir -p $HOME/.celestia-app/cosmovisor/genesis/bin
mv build/celestia-appd $HOME/.celestia-app/cosmovisor/genesis/bin/
rm -rf build

# cosmovisor
curl -Ls https://github.com/cosmos/cosmos-sdk/releases/download/cosmovisor%2Fv1.3.0/cosmovisor-v1.3.0-linux-amd64.tar.gz | tar xz
chmod 755 cosmovisor
sudo mv cosmovisor /usr/bin/cosmovisor

# create service
sudo tee /etc/systemd/system/celestia-appd.service > /dev/null << EOF
[Unit]
Description=celestia-testnet node service
After=network-online.target
[Service]
User=$USER
ExecStart=/usr/bin/cosmovisor run start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.celestia-app"
Environment="DAEMON_NAME=celestia-appd"
Environment="UNSAFE_SKIP_BACKUP=true"
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable celestia-appd

ln -s $HOME/.celestia-app/cosmovisor/genesis $HOME/.celestia-app/cosmovisor/current
sudo ln -s $HOME/.celestia-app/cosmovisor/current/bin/celestia-appd /usr/local/bin/celestia-appd

# config
celestia-appd config chain-id $CELESTIA_CHAIN_ID
celestia-appd config keyring-backend test
celestia-appd config node tcp://localhost:${CELESTIA_PORT}657

# init
celestia-appd init $NODENAME --chain-id $CELESTIA_CHAIN_ID

# download genesis and addrbook
curl -Ls https://snapshots.kjnodes.com/celestia-testnet/genesis.json > $HOME/.celestia-app/config/genesis.json
curl -Ls https://snapshots.kjnodes.com/celestia-testnet/addrbook.json > $HOME/.celestia-app/config/addrbook.json

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.005utia\"|" $HOME/.celestia-app/config/app.toml

# set peers and seeds
SEEDS='3f472746f46493309650e5a033076689996c8881@celestia-testnet.rpc.kjnodes.com:20659'
PEERS='1afcd97b0bf289700378e18b45dc1f927917bba0@65.109.92.79:11656,eaa763cde89fcf5a8fe44274a5ee3ce24bce2c5b@64.227.18.169:26656,0d0f0e4a149b50a96207523a5408611dae2796b6@198.199.82.109:26656,c2870ce12cfb08c4ff66c9ad7c49533d2bd8d412@178.170.47.171:26656,e8906342e657ace92e1ed8599f0949da8dd75fbd@146.19.24.52:20656,3584c49855123abdc16b01a47f9e1bea38a9db1b@154.26.155.102:26656'
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.celestia-app/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="50"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.celestia-app/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.celestia-app/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.celestia-app/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.celestia-app/config/app.toml

# set custom ports
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:20658\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:20657\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:20060\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:20656\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":20660\"%" $HOME/.celestia-app/config/config.toml
sed -i.bak -e "s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:20317\"%; s%^address = \":8080\"%address = \":20080\"%; s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:20090\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:20091\"%; s%^address = \"0.0.0.0:8545\"%address = \"0.0.0.0:20545\"%; s%^ws-address = \"0.0.0.0:8546\"%ws-address = \"0.0.0.0:20546\"%" $HOME/.celestia-app/config/app.toml

# snapshot
curl -L https://snapshots.kjnodes.com/celestia-testnet/snapshot_latest.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.celestia-app

# start service
sudo systemctl start celestia-appd

break
;;

"Create Wallet")
celestia-appd keys add $WALLET
echo "============================================================"
echo "Save address and mnemonic"
echo "============================================================"
CELESTIA_WALLET_ADDRESS=$(celestia-appd keys show $WALLET -a)
CELESTIA_VALOPER_ADDRESS=$(celestia-appd keys show $WALLET --bech val -a)
echo 'export CELESTIA_WALLET_ADDRESS='${CELESTIA_WALLET_ADDRESS} >> $HOME/.bash_profile
echo 'export CELESTIA_VALOPER_ADDRESS='${CELESTIA_VALOPER_ADDRESS} >> $HOME/.bash_profile
source $HOME/.bash_profile

break
;;

"Create Validator")
  celestia-appd tx staking create-validator \
--amount=1000000utia \
--pubkey=$(celestia-appd tendermint show-validator) \
--moniker=$NODENAME \
--chain-id=$CELESTIA_CHAIN_ID \
--evm-address=$EVM \
--orchestrator-address=$WALLET \
--commission-rate=0.05 \
--commission-max-rate=0.20 \
--commission-max-change-rate=0.01 \
--min-self-delegation=1 \
--from=$WALLET \
--gas-adjustment=1.4 \
--gas=auto \
--fees=1000utia \
-y
  
break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
