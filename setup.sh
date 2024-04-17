#!/bin/bash
CHAIN_NAME=mantrachain
DAEMON_NAME=mantrachaind
DAEMON_HOME=$HOME/.mantrachain
INSTALLATION_DIR=$(dirname "$(realpath "$0")")
CHAIN_ID='mantra-hongbai-1'
DENOM='uom'
SEEDS="d6016af7cb20cf1905bd61468f6a61decb3fd7c0@34.72.142.50:26656"
PEERS="da061f404690c5b6b19dd85d40fefde1fecf406c@34.68.19.19:26656,20db08acbcac9b7114839e63539da2802b848982@34.72.148.3:26656"
RPC="https://0gevmos-testnet-rpc.cryptonode.id:443"
GOPATH=$HOME/go
cd ${INSTALLATION_DIR}
if ! grep -q "export GOPATH=" ~/.profile; then
    echo "export GOPATH=$HOME/go" >> ~/.profile
    source ~/.profile
fi
if ! grep -q "export PATH=.*:/usr/local/go/bin" ~/.profile; then
    echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile
    source ~/.profile
fi
if ! grep -q "export PATH=.*$GOPATH/bin" ~/.profile; then
    echo "export PATH=$PATH:$GOPATH/bin" >> ~/.profile
    source ~/.profile
fi
GO_VERSION=$(go version 2>/dev/null | grep -oP 'go1\.22\.0')
if [ -z "$(echo "$GO_VERSION" | grep -E 'go1\.22\.0')" ]; then
    echo "Go is not installed or not version 1.22.0. Installing Go 1.22.0..."
    wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
    sudo rm -rf $(which go)
    sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
    rm go1.22.0.linux-amd64.tar.gz
else
    echo "Go version 1.22.0 is already installed."
fi
sudo apt -qy install curl git jq lz4 build-essential unzip
rm -rf ${CHAIN_NAME}
rm -rf ${DAEMON_HOME}
git clone -b testnet https://github.com/0glabs/0g-evmos.git
cd ${CHAIN_NAME}
make install
source ~/.profile
${DAEMON_NAME} version

mkdir -p ${DAEMON_HOME}/cosmovisor/genesis/bin
mkdir -p ${DAEMON_HOME}/cosmovisor/upgrades
cp $(which ${DAEMON_NAME}) ${DAEMON_HOME}/cosmovisor/genesis/bin/

sudo ln -s ${DAEMON_HOME}/cosmovisor/genesis ${DAEMON_HOME}/cosmovisor/current -f
sudo ln -s ${DAEMON_HOME}/cosmovisor/current/bin/${DAEMON_NAME} /usr/local/bin/${DAEMON_NAME} -f

read -p "Enter validator key name: " VALIDATOR_KEY_NAME
if [ -z "$VALIDATOR_KEY_NAME" ]; then
    echo "Error: No validator key name provided."
    exit 1
fi
read -p "Do you want to recover wallet? [y/N]: " RECOVER
RECOVER=$(echo "$RECOVER" | tr '[:upper:]' '[:lower:]')
if [[ "$RECOVER" == "y" || "$RECOVER" == "yes" ]]; then
    ${DAEMON_NAME} keys add $VALIDATOR_KEY_NAME --recover
else
    ${DAEMON_NAME} keys add $VALIDATOR_KEY_NAME
fi
${DAEMON_NAME} config keyring-backend file
${DAEMON_NAME} config chain-id $CHAIN_ID
${DAEMON_NAME} init $VALIDATOR_KEY_NAME --chain-id=$CHAIN_ID
${DAEMON_NAME} keys list
curl -Ls https://github.com/MANTRA-Finance/public/raw/main/mantrachain-hongbai/genesis.json > $HOME/.mantrachain/config/genesis.json
sed -i 's/seeds *=.*/seeds = "'"$SEEDS"'"/' ${DAEMON_HOME}/config/config.toml
sed -i 's/minimum-gas-prices *=.*/minimum-gas-prices = "0.0002'"$DENOM"'"/' ${DAEMON_HOME}/config/app.toml
sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "10"|' \
  ${DAEMON_HOME}/config/app.toml
read -p "Enter identity (leave blank for default 'CryptoNode.ID guide'): " INPUT_IDENTITY
INPUT_IDENTITY=${INPUT_IDENTITY:-"CryptoNode.ID guide"}
read -p "Enter website (leave blank for default 'https://cryptonode.id'): " INPUT_WEBSITE
INPUT_WEBSITE=${INPUT_WEBSITE:-"https://cryptonode.id"}
read -p "Enter your email (leave blank for default 't.me/CryptoNodeID'): " INPUT_EMAIL
INPUT_EMAIL=${INPUT_EMAIL:-"t.me/CryptoNodeID"}
read -p "Enter details (leave blank for default 'created using cryptonode.id helper'): " INPUT_DETAILS
INPUT_DETAILS=${INPUT_DETAILS:-"created using cryptonode.id helper"}
# Helper scripts
cd ${INSTALLATION_DIR}
rm -rf create_validator.sh unjail_validator.sh check_validator.sh start_${DAEMON_NAME}.sh stop_${DAEMON_NAME}.sh check_log.sh list_keys.sh check_balance.sh get_address.sh
read -p "Do you want to use custom port number prefix (y/N)? " use_custom_port
if [[ "$use_custom_port" =~ ^[Yy](es)?$ ]]; then
    read -p "Enter port number prefix (max 2 digits, not exceeding 50): " port_prefix
    while [[ "$port_prefix" =~ [^0-9] || ${#port_prefix} -gt 2 || $port_prefix -gt 50 ]]; do
        read -p "Invalid input, enter port number prefix (max 2 digits, not exceeding 50): " port_prefix
    done
    ${DAEMON_NAME} config node tcp://localhost:${port_prefix}657
    sed -i.bak -e "s%:1317%:${port_prefix}317%g; s%:8080%:${port_prefix}080%g; s%:9090%:${port_prefix}090%g; s%:9091%:${port_prefix}091%g; s%:8545%:${port_prefix}545%g; s%:8546%:${port_prefix}546%g; s%:6065%:${port_prefix}065%g" ${DAEMON_HOME}/config/app.toml
    sed -i.bak -e "s%:26658%:${port_prefix}658%g; s%:26657%:${port_prefix}657%g; s%:6060%:${port_prefix}060%g; s%:26656%:${port_prefix}656%g; s%:26660%:${port_prefix}660%g" ${DAEMON_HOME}/config/config.toml
fi

LATEST_HEIGHT=$(curl -s --max-time 3 --retry 2 --retry-connrefused $RPC/block | jq -r .result.block.header.height)
TRUST_HEIGHT=$((LATEST_HEIGHT - 2000))
TRUST_HASH=$(curl -s --max-time 3 --retry 2 --retry-connrefused "$RPC/block?height=$TRUST_HEIGHT" | jq -r .result.block_id.hash)

if [ -n "$PEERS" ] && [ -n "$RPC" ] && [ -n "$LATEST_HEIGHT" ] && [ -n "$TRUST_HEIGHT" ] && [ -n "$TRUST_HASH" ]; then
    sed -i.bak \
        -e "/\[statesync\]/,/^\[/{s/\(enable = \).*$/\1true/}" \
        -e "/^rpc_servers =/ s|=.*|= \"$RPC,$RPC\"|;" \
        -e "/^trust_height =/ s/=.*/= $TRUST_HEIGHT/;" \
        -e "/^trust_hash =/ s/=.*/= \"$TRUST_HASH\"/" \
        -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" \
        ${DAEMON_HOME}/config/config.toml
    echo -e "\nLATEST_HEIGHT: $LATEST_HEIGHT\nTRUST_HEIGHT: $TRUST_HEIGHT\nTRUST_HASH: $TRUST_HASH\nPEERS: $PEERS\n\nALL IS FINE"
else
    echo -e "\nError: One or more variables are empty. Please try again or change RPC\nExiting...\n"
fi

tee create_validator.sh > /dev/null <<EOF
#!/bin/bash
${DAEMON_NAME} tx staking create-validator \\
  --amount=1000000${DENOM} \\
  --pubkey=\$(${DAEMON_NAME} tendermint show-validator) \\
  --moniker=${VALIDATOR_KEY_NAME} \\
  --chain-id=${CHAIN_ID} \\
  --commission-rate=0.05 \\
  --commission-max-rate=0.20 \\
  --commission-max-change-rate=0.01 \\
  --min-self-delegation=1000000 \\
  --from=${VALIDATOR_KEY_NAME} \\
  --identity="${INPUT_IDENTITY}" \\
  --website="${INPUT_WEBSITE}" \\
  --details="${INPUT_DETAILS}" \\
  --gas=auto --gas-adjustment 2 --gas-prices=0.0002${DENOM}
EOF
chmod +x create_validator.sh
tee unjail_validator.sh > /dev/null <<EOF
#!/bin/bash
${DAEMON_NAME} tx slashing unjail \\
 --from=$VALIDATOR_KEY_NAME \\
 --chain-id="$CHAIN_ID" \\
 --gas=auto --gas-adjustment 2 --gas-prices=0.0002${DENOM}
EOF
chmod +x unjail_validator.sh
tee check_validator.sh > /dev/null <<EOF
#!/bin/bash
${DAEMON_NAME} query tendermint-validator-set | grep "\$(${DAEMON_NAME} tendermint show-address)"
EOF
chmod +x check_validator.sh

tee start_${DAEMON_NAME}.sh > /dev/null <<EOF
sudo systemctl daemon-reload
sudo systemctl enable ${DAEMON_NAME}
sudo systemctl restart ${DAEMON_NAME}
EOF
chmod +x start_${DAEMON_NAME}.sh
tee stop_${DAEMON_NAME}.sh > /dev/null <<EOF
sudo systemctl stop ${DAEMON_NAME}
EOF
chmod +x stop_${DAEMON_NAME}.sh
tee check_log.sh > /dev/null <<EOF
sudo journalctl -u ${DAEMON_NAME} -f
EOF
chmod +x check_log.sh

echo "${DAEMON_NAME} keys list" > list_keys.sh && chmod +x list_keys.sh
echo "${DAEMON_NAME} q bank balances $(${DAEMON_NAME} keys show $VALIDATOR_KEY_NAME -a)" > check_balance.sh && chmod +x check_balance.sh
tee get_address.sh > /dev/null <<EOF
#!/bin/bash
echo "0x\$(evmosd debug addr \$(evmosd keys show ${VALIDATOR_KEY_NAME} -a) | grep hex | awk '{print $3}')"
EOF
chmod +x get_address.sh

if ! command -v cosmovisor > /dev/null 2>&1 || ! which cosmovisor &> /dev/null; then
    wget https://github.com/cosmos/cosmos-sdk/releases/download/cosmovisor%2Fv1.5.0/cosmovisor-v1.5.0-linux-amd64.tar.gz
    tar -xvzf cosmovisor-v1.5.0-linux-amd64.tar.gz
    rm cosmovisor-v1.5.0-linux-amd64.tar.gz
    sudo cp cosmovisor /usr/local/bin/cosmovisor
fi
sudo tee /etc/systemd/system/${DAEMON_NAME}.service > /dev/null <<EOF
[Unit]
Description=${CHAIN_NAME} daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=always
RestartSec=3
LimitNOFILE=infinity

Environment="DAEMON_NAME=${DAEMON_NAME}"
Environment="DAEMON_HOME=${DAEMON_HOME}"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"

[Install]
WantedBy=multi-user.target
EOF
if ! grep -q 'export DAEMON_NAME=' $HOME/.profile; then
    echo "export DAEMON_NAME=${DAEMON_NAME}" >> $HOME/.profile
fi
if ! grep -q 'export DAEMON_HOME=' $HOME/.profile; then
    echo "export DAEMON_HOME=${DAEMON_HOME}" >> $HOME/.profile
fi
if ! grep -q 'export DAEMON_RESTART_AFTER_UPGRADE=' $HOME/.profile; then
    echo "export DAEMON_RESTART_AFTER_UPGRADE=true" >> $HOME/.profile
fi
if ! grep -q 'export DAEMON_ALLOW_DOWNLOAD_BINARIES=' $HOME/.profile; then
    echo "export DAEMON_ALLOW_DOWNLOAD_BINARIES=false" >> $HOME/.profile
fi
if ! grep -q 'export CHAIN_ID=' $HOME/.profile; then
    echo "export CHAIN_ID=${CHAIN_ID}" >> $HOME/.profile
fi
source $HOME/.profile

sudo systemctl daemon-reload
read -p "Do you want to enable the ${DAEMON_NAME} service? (y/N): " ENABLE_SERVICE
if [[ "$ENABLE_SERVICE" =~ ^[Yy](es)?$ ]]; then
    sudo systemctl enable ${DAEMON_NAME}.service
else
    echo "Skipping enabling ${DAEMON_NAME} service."
fi