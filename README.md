### Prerequisite :
#### Ensure 'git' already installed
    apt-get update -y && apt-get install git -y
### Steps
#### Clone this repository :
    git clone https://github.com/CryptoNodeID/mantrachain.git
#### run setup command : 
    cd mantrachain && chmod ug+x *.sh && ./setup.sh
#### follow the instruction and then run below command to start the node :
    ./start_mantrachain.sh && ./check_log.sh
### Available helper tools :
    ./start_mantrachain.sh
    ./stop_mantrachain.sh
    ./check_log.sh
    
    ./create_validator.sh
    ./unjail_validator.sh
    ./check_validator.sh

    ./list_keys.sh
    ./check_balance.sh
    ./get_address.sh
