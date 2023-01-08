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
SEEDS=''
PEERS='e5fa03c0d18d1e51182a7d787fc25c3e57f03d7b@celestia-testnet.nodejumper.io:29656,4e409a7e4e7cd930a9cfb0a97f5b51b50cd70c86@65.21.199.148:26628,5dcb5202d52f80be78363a158386d12a53ba87b0@195.181.245.34:26656,13a8bcd8c0487467518e577fcb9179c1027cd472@65.109.30.12:60556,04da9228a305d70c395321ffa1c73c1ff1632371@135.181.198.220:26656,3f64b15d737c1d07ac844716535e85c2617625a6@144.76.176.154:26656,0bd6f3332fd4da091c8e0a1ba9e0c43c582f2bfd@194.163.143.122:26656,9da255ee3035050e6281e30a8ab5c0230099476c@195.201.241.104:20656,978a58a594c5c588336c72697233e25846e35125@84.46.249.54:26656,dc95a6170f60eb4b1eed301a12b1f61940861838@135.181.207.192:26656,1fc51f988cc618e0f00d6ae9710e90dd6755f418@65.21.132.27:11656,d78a84fc4262d565a9493d94001612244d53091d@35.240.201.29:26656,be7ceaf63e894e2a248061f5f82d7e348c95e69c@65.21.190.12:20656,0f1b828c0250192a01a80a7dcff56c3399efd06c@185.135.137.246:26661,98a52035f9d04e360f4f34aaa3bf72b91016c034@217.76.50.109:26656,13242037063e270f89d2d5fcfda891e417823a91@45.94.58.203:26661,279a72757e59a19fc8ff53f45e9df0cde1cb6cf3@34.142.222.195:26656,50411c4b8346449731bb81725aaf38850e865bd8@65.109.34.133:60756,6c87a8be23b8f7cdec4ec66cfcff5c13d6114ed9@135.181.3.38:28656,1877a1394db9202040f9bde2b3e5405eaa49828d@38.242.229.210:26656,19c378bba2321764558785357074c71ef295e58b@161.97.149.234:26656,d0dc86dec5caf747e1aa7d3954ed43ad3509876b@142.132.152.46:15656,321649cf5d2ce2352ffb0c20745d0de607b4ec2a@5.161.128.92:26656,98508ad43c9ba692b4d189795e81bf4ec1cd3252@161.97.146.59:26656,d37383963838607944841a004c9b00a232d0f8ca@167.99.194.123:26656,ef49ca014e6a5048050da458038d0d2a9051f3b8@161.97.136.149:26656,d56748be04b245936ebdfa8e9b5db4e4c2cd9c03@194.180.176.140:26656,99b17fd83d2b2f0b3d9725dc07c48322ef3beb42@75.119.135.144:20656,dea18507c971ea4e044e6304fe8b6f010cbbfee8@65.108.79.246:26676,7ca86c0d9f708f2a24aa1526d2ac5abf03d52eb6@65.21.245.146:26656,6b93e34a6d00b6203cba56c9c765615ca68b2676@185.135.137.212:26661,9818639770512f00bcf661941c6485e6109dbdd3@185.135.137.251:26661,1ac919cd06b1398c9b146144bc574ace86d330c0@161.97.148.146:26656,9ff54a3d9e88630b993f22f6d3ff9e14ddd79864@138.201.139.207:23656,021914827e4b117ef8c43386371e7a2f39f73654@168.119.124.130:22656,857ea6ee66e3c09dcc7dc54095a3793e50e14eea@34.125.102.243:11656,2fd31d176d38820d3673ae68a48079a8a6539fda@217.76.58.35:26656,718105c1a17a0a5577796550469584988529a90b@89.117.55.108:26656,78c9e7a206b7063b7f54e5c25f208b2a513b3491@95.216.242.177:20656,f98ee535cea1baf4a8fa438d1cd4e69ac836791f@65.21.234.47:26826,536e50a29c20e83687f64e77ee5d84715eb61aa2@38.242.225.86:26656,8bb8e34ac6eb4ddb927bb1cbbd44357683123af1@176.9.98.24:30542,757810ca2a2af5ef537704a30a154fb592988fbc@14.162.220.73:20056,af142892a64d2ae60b3719df373c0a98597a6855@65.109.5.243:26656,e6c61e721716c0ada288462264fbd6366b2f3107@154.53.32.169:33656,4d987157249cee38b1a2df50548816e4304f5287@113.53.233.58:26656,d71ea54242bcf9b94ee842df2ac486388b24a4b6@203.154.164.85:26656,dc06b9495afa1fea6293bc4c3765e134f0adf04a@217.76.59.115:26656,e7dc98812ba79276f045ed080a6910540ce37e2a@159.69.241.155:20656,eb372537fe0ebbb3944f5c5a0f18671b41f46fc1@144.91.108.185:26656,a10349d07a2f238b6183d48cdd9d75f6a4b54998@149.102.138.37:26656'
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
