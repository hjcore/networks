#!/bin/sh

# --- helper functions for logs ---
info()
{
    echo '[INFO] ' "$@"
}
warn()
{
    echo '[WARN] ' "$@" >&2
}
fatal()
{
    echo '[ERROR] ' "$@" >&2
    exit 1
}

# install docker
install_docker_for_debian() {
    sudo apt-get -y  remove docker docker-engine docker.io containerd runc
    sudo apt-get -y update
    sudo apt-get -y  install \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg2 \
        software-properties-common 
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
    sudo add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/debian \
       $(lsb_release -cs) \
       stable" 
    sudo apt-get -y update
    sudo apt-get -y install docker-ce docker-ce-cli containerd.io
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo apt -y install python3-pip  rsync
    sudo pip3 install docker docker-compose
}

install_docker_for_ubuntu() {
    sudo apt-get update -y
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable"
    sudo apt-get update -y
    sudo apt-get install docker-ce docker-ce-cli containerd.io -y
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo apt install -y python3-pip rsync
    sudo pip3 install docker docker-compose
}

install_docker_for_centos() {
    yum remove docker \
                      docker-client \
                      docker-client-latest \
                      docker-common \
                      docker-latest \
                      docker-latest-logrotate \
                      docker-logrotate \
                      docker-engine ;  \
    yum install -y yum-utils \
      device-mapper-persistent-data \
      lvm2 && \
    yum-config-manager \
       --add-repo \
       https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io
    ID=$(cat /etc/os-release|grep '^VERSION_ID='|awk -F'"' '{print $2}')
    if [[ "$ID" -eq 8 ]];then
        dnf -y install https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm
    fi
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
    sudo systemctl enable docker
    sudo systemctl start docker
    yum install -y python3 python3-pip rsync
    pip3 install docker docker-compose
}

install_docker_for_alpine() {
   version=$(cat /etc/os-release|grep 'VERSION_ID'|awk -F'=' '{print $2}'|awk -F'.' '{print $1"."$2}')
   cat <<EOF > /etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/v${version}/main
http://dl-cdn.alpinelinux.org/alpine/v${version}/community
# http://dl-cdn.alpinelinux.org/alpine/edge/main
# http://dl-cdn.alpinelinux.org/alpine/edge/community
# http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF
   apk add -U docker
   rc-update add docker
   /etc/init.d/docker start
   apk add -U python3
   pip3 install docker docker-compose
}

# main

install_docker() {
    if ! command -v docker; then
        NAME=$(cat /etc/os-release|grep '^NAME='|tr [A-Z] [a-z])
        case $NAME in
          *"alpine"*)
            echo alpine
            install_docker_for_alpine
            ;;
          *"debian"*)
            echo debian
            install_docker_for_debian
            ;;
          *"ubuntu"*)
            echo ubuntu
            install_docker_for_ubuntu
            ;;
          *"centos"*)
            echo centos
            install_docker_for_centos
            ;;
        esac
    else
	echo docker has been installed
    fi
} 

setup_env() {
    SUDO=sudo
    if [ $(id -u) -eq 0 ]; then
        SUDO=
    fi
    if [ -z "${MONIKER}" ]; then
        MONIKER=$(tr -dc a-z0-9 </dev/urandom | head -c 6)
    fi
    info $MONIKER

    # --- use binary install directory if defined or create default ---
    if [ -n "${INSTALL_GOTABITD_BIN_DIR}" ]; then
        BIN_DIR=${INSTALL_GOTABITD_BIN_DIR}
    else
        # --- use /usr/local/bin if root can write to it, otherwise use /opt/bin if it exists
        BIN_DIR=/usr/local/bin
        if ! $SUDO sh -c "touch ${BIN_DIR}/gotabitd-ro-test && rm -rf ${BIN_DIR}/gotabitd-ro-test"; then
            if [ -d /opt/bin ]; then
                BIN_DIR=/opt/bin
            fi
        fi
    fi
}

# --- create temporary directory and cleanup when done ---
setup_tmp() {
    TMP_DIR=$(mktemp -d -t gotabitd-install.XXXXXXXXXX)
    TMP_HASH=${TMP_DIR}/gotabitd.hash
    TMP_BIN=${TMP_DIR}/gotabitd.bin
    cleanup() {
        code=$?
        set +e
        trap - EXIT
        rm -rf ${TMP_DIR}
        exit $code
    }
    trap cleanup INT EXIT
}
# --- verify existence of network downloader executable ---
verify_downloader() {
    # Return failure if it doesn't exist or is no executable
    [ -x "$(command -v $1)" ] || return 1

    # Set verified executable as our downloader program and return success
    DOWNLOADER=$1
    return 0
}

download() {
    [ $# -eq 2 ] || fatal 'download needs exactly 2 arguments'
    case $DOWNLOADER in
        curl)
            curl -o $1 -sfL $2
            ;;
        wget)
            wget -qO $1 $2
            ;;
        *)
            fatal "Incorrect executable '$DOWNLOADER'"
            ;;
    esac

    # Abort if download command failed
    [ $? -eq 0 ] || fatal 'Download failed'
}

# --- setup permissions and move binary to system directory ---
setup_binary() {
    info "Installing gotabit to ${BIN_DIR}/gotabitd"
    # $SUDO mv -f ${TMP_BIN} ${BIN_DIR}/gotabitd
	$SUDO tar -zxf ${TMP_BIN} -C ${BIN_DIR} 
	$SUDO mv  ${BIN_DIR}/build/gotabitd-linux-amd64 ${BIN_DIR}/gotabitd && $SUDO rmdir ${BIN_DIR}/build
    $SUDO chown root:root ${BIN_DIR}/gotabitd
    $SUDO chmod 755 ${BIN_DIR}/gotabitd
}

# --- download binary from github url ---
download_binary() {
    # BIN_URL=${GITHUB_URL}/download/${VERSION_GOTABITD}/gotabit${SUFFIX}
    GOTABITD_VERSION=v1.0.1
    BIN_URL=https://github.com/gotabit/gotabit/releases/download/$GOTABITD_VERSION/gotabitd-$GOTABITD_VERSION-linux-amd64.tar.gz
    info "Downloading binary ${BIN_URL}"
    download ${TMP_BIN} ${BIN_URL}
	
}

download_and_verify() {
    verify_downloader curl || verify_downloader wget || fatal 'Can not find curl or wget for downloading files'
	setup_tmp
	download_binary
	setup_binary
}

setup_docker_start() {
	cat <<EOF > start.sh
#!/bin/sh
init() {
    if [ ! -f /root/.gotabit/config/genesis.json ]; then
		apk add -U curl
        gotabitd init \$MONIKER --chain-id gotabit-test-1
        
        #Set the base repo URL for the testnet & retrieve peers
        CHAIN_REPO='https://raw.githubusercontent.com/hjcore/networks/master/gotabit-test-1'
        
        # persistent peers
        export PEERS=\$(curl -s \$CHAIN_REPO/persistent_peers.txt)
        # check it worked
        echo \$PEERS
        sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"\$PEERS\"/" ~/.gotabit/config/config.toml
        
            # seeds
        export SEEDS=\$(curl -s \$CHAIN_REPO/seeds.txt)
        echo \$SEEDS
        sed -i.bak -e "s/^seeds *=.*/seeds = \"\$SEEDS\"/" ~/.gotabit/config/config.toml
        
        # gas price
        sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0025ugtb\"/" ~/.gotabit/config/app.toml
        
        # genesis
        curl -fsSL \$CHAIN_REPO/genesis.json > ~/.gotabit/config/genesis.json
    fi
}

start () {
        gotabitd start --rpc.laddr tcp://0.0.0.0:26657
}

init
start
EOF
    chmod +x start.sh && $SUDO mv start.sh ${BIN_DIR}/start.sh
}

run_container() {
    echo docker run \
		--name gotabitd \
		-p 1317:1317 \
		-p 26656:26656 \
		-p 26657:26657 \
		-v $PWD/.gotabit:/root/.gotabit \
		-v ${BIN_DIR}/start.sh:/start.sh \
		-e MONIKER=$MONIKER \
		gotabit/gotabit:1.0.0 /start.sh
		# -v ${BIN_DIR}/gotabitd:/usr/bin/gotabitd \

    docker rm -f gotabitd; docker run \
		--name gotabitd \
		-p 1317:1317 \
		-p 26656:26656 \
		-p 26657:26657 \
		-v $PWD/.gotabit:/root/.gotabit \
		-v ${BIN_DIR}/start.sh:/start.sh \
		-e MONIKER=$MONIKER \
		gotabit/gotabit:1.0.0 /start.sh
		# -v ${BIN_DIR}/gotabitd:/usr/bin/gotabitd \
} 

# run gotabtid
# docker run -v ./gotabit:/

# main
install_docker
setup_env
download_and_verify
setup_docker_start
run_container
