# Functions

accept_salt_key_local() {
  echo "Accept the key locally on the master" >> $SETUPLOG 2>&1
  # Accept the key locally on the master
  salt-key -ya $MINION_ID

}

accept_salt_key_remote() {
  echo "Accept the key remotely on the master" >> $SETUPLOG 2>&1
  # Delete the key just in case.
  ssh -i /root/.ssh/so.key socore@$MSRV sudo salt-key -d $MINION_ID -y
  salt-call state.apply ca
  ssh -i /root/.ssh/so.key socore@$MSRV sudo salt-key -a $MINION_ID -y

}

add_master_hostfile() {
  echo "Checking if I can resolve master. If not add to hosts file" >> $SETUPLOG 2>&1
  # Pop up an input to get the IP address
  MSRVIP=$(whiptail --title "Security Onion Setup" --inputbox \
  "Enter your Master Server IP Address" 10 60 X.X.X.X 3>&1 1>&2 2>&3)

}

add_socore_user_master() {

  echo "Add socore on the master" >>~/sosetup.log 2>&1
  # Add user "socore" to the master. This will be for things like accepting keys.
  if [ $OS == 'centos' ]; then
    local ADDUSER=adduser
  else
    local ADDUSER=useradd
  fi
  groupadd --gid 939 socore
  $ADDUSER --uid 939 --gid 939 --home-dir /opt/so socore
  # Set the password for socore that we got during setup
  echo socore:$COREPASS1 | chpasswd --crypt-method=SHA512

}

add_socore_user_notmaster() {
  echo "Add socore user on non master" >> $SETUPLOG 2>&1
  # Add socore user to the non master system. Probably not a bad idea to make system user
  groupadd --gid 939 socore
  $ADDUSER --uid 939 --gid 939 --home-dir /opt/so --no-create-home socore

}

# Create an auth pillar so that passwords survive re-install
auth_pillar(){

  if [ ! -f /opt/so/saltstack/pillar/auth.sls ]; then
    echo "Creating Auth Pillar" >> $SETUPLOG 2>&1
    mkdir -p /opt/so/saltstack/pillar
    echo "auth:" >> /opt/so/saltstack/pillar/auth.sls
    echo "  mysql: $MYSQLPASS" >> /opt/so/saltstack/pillar/auth.sls
    echo "  fleet: $FLEETPASS" >> /opt/so/saltstack/pillar/auth.sls
  fi

}

# Enable Bro Logs
bro_logs_enabled() {
  echo "Enabling Bro Logs" >> $SETUPLOG 2>&1

  echo "brologs:" > pillar/brologs.sls
  echo "  enabled:" >> pillar/brologs.sls

  if [ $MASTERADV == 'ADVANCED' ]; then
    for BLOG in ${BLOGS[@]}; do
      echo "    - $BLOG" | tr -d '"' >> pillar/brologs.sls
    done
  else
    echo "    - conn" >> pillar/brologs.sls
    echo "    - dce_rpc" >> pillar/brologs.sls
    echo "    - dhcp" >> pillar/brologs.sls
    echo "    - dhcpv6" >> pillar/brologs.sls
    echo "    - dnp3" >> pillar/brologs.sls
    echo "    - dns" >> pillar/brologs.sls
    echo "    - dpd" >> pillar/brologs.sls
    echo "    - files" >> pillar/brologs.sls
    echo "    - ftp" >> pillar/brologs.sls
    echo "    - http" >> pillar/brologs.sls
    echo "    - intel" >> pillar/brologs.sls
    echo "    - irc" >> pillar/brologs.sls
    echo "    - kerberos" >> pillar/brologs.sls
    echo "    - modbus" >> pillar/brologs.sls
    echo "    - mqtt" >> pillar/brologs.sls
    echo "    - notice" >> pillar/brologs.sls
    echo "    - ntlm" >> pillar/brologs.sls
    echo "    - openvpn" >> pillar/brologs.sls
    echo "    - pe" >> pillar/brologs.sls
    echo "    - radius" >> pillar/brologs.sls
    echo "    - rfb" >> pillar/brologs.sls
    echo "    - rdp" >> pillar/brologs.sls
    echo "    - signatures" >> pillar/brologs.sls
    echo "    - sip" >> pillar/brologs.sls
    echo "    - smb_files" >> pillar/brologs.sls
    echo "    - smb_mapping" >> pillar/brologs.sls
    echo "    - smtp" >> pillar/brologs.sls
    echo "    - snmp" >> pillar/brologs.sls
    echo "    - software" >> pillar/brologs.sls
    echo "    - ssh" >> pillar/brologs.sls
    echo "    - ssl" >> pillar/brologs.sls
    echo "    - syslog" >> pillar/brologs.sls
    echo "    - telnet" >> pillar/brologs.sls
    echo "    - tunnel" >> pillar/brologs.sls
    echo "    - weird" >> pillar/brologs.sls
    echo "    - mysql" >> pillar/brologs.sls
    echo "    - socks" >> pillar/brologs.sls
    echo "    - x509" >> pillar/brologs.sls
  fi
}

calculate_useable_cores() {

  # Calculate reasonable core usage
  local CORES4BRO=$(( $CPUCORES/2 - 1 ))
  LBPROCSROUND=$(printf "%.0f\n" $CORES4BRO)
  # We don't want it to be 0
  if [ "$LBPROCSROUND" -lt 1 ]; then
    LBPROCS=1
  else
    LBPROCS=$LBPROCSROUND
  fi

}

checkin_at_boot() {
  echo "Enabling checkin at boot" >> $SETUPLOG 2>&1
  echo "startup_states: highstate" >> /etc/salt/minion
}

check_hive_init_then_reboot() {
  WAIT_STEP=0
  MAX_WAIT=100
    until [ -f /opt/so/state/thehive.txt ] ; do
    WAIT_STEP=$(( ${WAIT_STEP} + 1 ))
    echo "Waiting on the_hive to init...Attempt #$WAIT_STEP"
  	  if [ ${WAIT_STEP} -gt ${MAX_WAIT} ]; then
  			  echo "ERROR: We waited ${MAX_WAIT} seconds but the_hive is not working."
  			  exit 5
  	  fi
  		  sleep 1s;
    done
    docker stop so-thehive
    docker rm so-thehive
    shutdown -r now
}

check_socore_pass() {

  if [ $COREPASS1 == $COREPASS2 ]; then
    SCMATCH=yes
  else
    whiptail_passwords_dont_match
  fi

}

chown_salt_master() {

  echo "Chown the salt dirs on the master for socore" >> $SETUPLOG 2>&1
  chown -R socore:socore /opt/so

}

clear_master() {
  # Clear out the old master public key in case this is a re-install.
  # This only happens if you re-install the master.
  if [ -f /etc/salt/pki/minion/minion_master.pub ]; then
    echo "Clearing old master key" >> $SETUPLOG 2>&1
    rm /etc/salt/pki/minion/minion_master.pub
    service salt-minion restart
  fi

}

configure_minion() {

  # You have to pass the TYPE to this function so it knows if its a master or not
  local TYPE=$1
  echo "Configuring minion type as $TYPE" >> $SETUPLOG 2>&1
  touch /etc/salt/grains
  echo "role: so-$TYPE" > /etc/salt/grains
  if [ $TYPE == 'master' ] || [ $TYPE == 'eval' ]; then
    echo "master: $HOSTNAME" > /etc/salt/minion
    echo "id: $MINION_ID" >> /etc/salt/minion
    echo "mysql.host: '$MAINIP'" >> /etc/salt/minion
    echo "mysql.port: 3306" >> /etc/salt/minion
    echo "mysql.user: 'root'" >> /etc/salt/minion
    if [ ! -f /opt/so/saltstack/pillar/auth.sls ]; then
      echo "mysql.pass: '$MYSQLPASS'" >> /etc/salt/minion
    else
      OLDPASS=$(cat /opt/so/saltstack/pillar/auth.sls | grep mysql | awk {'print $2'})
      echo "mysql.pass: '$OLDPASS'" >> /etc/salt/minion
    fi
  else
    echo "master: $MSRV" > /etc/salt/minion
    echo "id: $MINION_ID" >> /etc/salt/minion

  fi

  echo "use_superseded:" >> /etc/salt/minion
  echo "  - module.run" >> /etc/salt/minion

  service salt-minion restart

}

copy_master_config() {

  # Copy the master config template to the proper directory
  cp files/master /etc/salt/master
  # Restart the service so it picks up the changes -TODO Enable service on CentOS
  service salt-master restart

}

copy_minion_tmp_files() {

  if [ $INSTALLTYPE == 'MASTERONLY' ] || [ $INSTALLTYPE == 'EVALMODE' ]; then
    echo "rsyncing all files in $TMP to /opt/so/saltstack" >> $SETUPLOG 2>&1
    rsync -a -v $TMP/ /opt/so/saltstack/ >> $SETUPLOG 2>&1
  else
    echo "scp all files in $TMP to master /opt/so/saltstack" >> $SETUPLOG 2>&1
    scp -prv -i /root/.ssh/so.key $TMP/* socore@$MSRV:/opt/so/saltstack >> $SETUPLOG 2>&1
  fi

  }

copy_ssh_key() {

  # Generate SSH key
  mkdir -p /root/.ssh
  cat /dev/zero | ssh-keygen -f /root/.ssh/so.key -t rsa -q -N ""
  chown -R $SUDO_USER:$SUDO_USER /root/.ssh
  #Copy the key over to the master
  ssh-copy-id -f -i /root/.ssh/so.key socore@$MSRV

}

network_setup() {
  echo "Setting up Bond" >> $SETUPLOG 2>&1

  # Set the MTU
  if [ "$NSMSETUP" != 'ADVANCED' ]; then
    MTU=1500
  fi

  # Create the bond interface
  nmcli con add ifname bond0 con-name "bond0" type bond mode 0 -- \
    ipv4.method disabled \
    ipv6.method link-local \
    ethernet.mtu $MTU \
    connection.autoconnect "yes" >> $SETUPLOG 2>&1

  for BNIC in ${BNICS[@]}; do
    # Strip the quotes from the NIC names
    BONDNIC="$(echo -e "${BNIC}" | tr -d '"')"
      # Turn off various offloading settings for the interface
    for i in rx tx sg tso ufo gso gro lro; do
          ethtool -K $BONDNIC $i off >> $SETUPLOG 2>&1
    done
    # Create the slave interface and assign it to the bond
    nmcli con add type ethernet ifname $BONDNIC con-name "bond0-slave-$BONDNIC" master bond0 -- \
    ethernet.mtu $MTU \
    connection.autoconnect "yes" >> $SETUPLOG 2>&1
    # Bring the slave interface up
    nmcli con up bond0-slave-$BONDNIC >> $SETUPLOG 2>&1
  done
  # Replace the variable string in the network script
  sed -i "s/\$MAININT/${MAININT}/g" ./install_scripts/disable-checksum-offload.sh >> $SETUPLOG 2>&1
  # Copy the checksum offload script to prevent issues with packet capture
  cp ./install_scripts/disable-checksum-offload.sh /etc/NetworkManager/dispatcher.d/disable-checksum-offload.sh  >> $SETUPLOG 2>&1
}

detect_os() {

  # Detect Base OS
  echo "Detecting Base OS" >> $SETUPLOG 2>&1
  if [ -f /etc/redhat-release ]; then
    OS=centos
    yum -y install bind-utils
  elif [ -f /etc/os-release ]; then
    OS=ubuntu
    apt install -y network-manager
    /bin/systemctl enable network-manager
    /bin/systemctl start network-manager
  else
    echo "We were unable to determine if you are using a supported OS." >> $SETUPLOG 2>&1
    exit
  fi

}

docker_install() {

  if [ $OS == 'centos' ]; then
    yum clean expire-cache
    yum -y install yum-utils device-mapper-persistent-data lvm2 openssl
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum -y update
    yum -y install docker-ce python36-docker
    if [ $INSTALLTYPE != 'EVALMODE'  ]; then
      docker_registry
    fi
    echo "Restarting Docker" >> $SETUPLOG 2>&1
    systemctl restart docker
    systemctl enable docker

  else
    if [ $INSTALLTYPE == 'MASTERONLY' ] || [ $INSTALLTYPE == 'EVALMODE' ]; then
      apt-get update >> $SETUPLOG 2>&1
      apt-get -y install docker-ce >> $SETUPLOG 2>&1
      if [ $INSTALLTYPE != 'EVALMODE'  ]; then
        docker_registry >> $SETUPLOG 2>&1
      fi
      echo "Restarting Docker" >> $SETUPLOG 2>&1
      systemctl restart docker >> $SETUPLOG 2>&1
    else
      apt-key add $TMP/gpg/docker.pub >> $SETUPLOG 2>&1
      add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >> $SETUPLOG 2>&1
      apt-get update >> $SETUPLOG 2>&1
      apt-get -y install docker-ce >> $SETUPLOG 2>&1
      docker_registry >> $SETUPLOG 2>&1
      echo "Restarting Docker" >> $SETUPLOG 2>&1
      systemctl restart docker >> $SETUPLOG 2>&1
    fi
    echo "Using pip3 to install docker-py for salt"
    pip3 install docker
  fi

}

docker_registry() {

  echo "Setting up Docker Registry" >> $SETUPLOG 2>&1
  mkdir -p /etc/docker >> $SETUPLOG 2>&1
  # Make the host use the master docker registry
  echo "{" > /etc/docker/daemon.json
  echo "  \"registry-mirrors\": [\"https://$MSRV:5000\"]" >> /etc/docker/daemon.json
  echo "}" >> /etc/docker/daemon.json
  echo "Docker Registry Setup - Complete" >> $SETUPLOG 2>&1

}

es_heapsize() {

  # Determine ES Heap Size
  if [ $TOTAL_MEM -lt 8000 ] ; then
      ES_HEAP_SIZE="600m"
  elif [ $TOTAL_MEM -ge 100000 ]; then
      # Set a max of 25GB for heap size
      # https://www.elastic.co/guide/en/elasticsearch/guide/current/heap-sizing.html
      ES_HEAP_SIZE="25000m"
  else
      # Set heap size to 25% of available memory
      ES_HEAP_SIZE=$(($TOTAL_MEM / 4))"m"
  fi

}

eval_mode_hostsfile() {

  echo "127.0.0.1   $HOSTNAME" >> /etc/hosts

}

filter_nics() {

  # Filter the NICs that we don't want to see in setup
  FNICS=$(ip link | grep -vw $MNIC | awk -F: '$0 !~ "lo|vir|veth|br|docker|wl|^[^0-9]"{print $2 " \"" "Interface" "\"" " OFF"}')

}

generate_passwords(){
  # Generate Random Passwords for Things
  MYSQLPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
  FLEETPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
  HIVEKEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
  CORTEXKEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
  SENSORONIKEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
}

get_filesystem_nsm(){
  FSNSM=$(df /nsm | awk '$3 ~ /[0-9]+/ { print $2 * 1000 }')
}

get_log_size_limit() {

  DISK_DIR="/"
  if [ -d /nsm ]; then
    DISK_DIR="/nsm"
  fi
  DISK_SIZE_K=`df $DISK_DIR |grep -v "^Filesystem" | awk '{print $2}'`
  PERCENTAGE=85
  DISK_SIZE=DISK_SIZE_K*1000
  PERCENTAGE_DISK_SPACE=`echo $(($DISK_SIZE*$PERCENTAGE/100))`
  LOG_SIZE_LIMIT=$(($PERCENTAGE_DISK_SPACE/1000000000))

}

get_filesystem_root(){
  FSROOT=$(df / | awk '$3 ~ /[0-9]+/ { print $2 * 1000 }')
}

get_main_ip() {

  # Get the main IP address the box is using
  MAINIP=$(ip route get 1 | awk '{print $NF;exit}')
  MAININT=$(ip route get 1 | awk '{print $5;exit}')

}

got_root() {

  # Make sure you are root
  if [ "$(id -u)" -ne 0 ]; then
          echo "This script must be run using sudo!"
          exit 1
  fi

}

install_cleanup() {

  # Clean up after ourselves
  rm -rf /root/installtmp

}

install_python3() {

  echo "Installing Python3"

  if [ $OS == 'ubuntu' ]; then
    apt-get -y install python3-pip gcc python3-dev
  elif [ $OS == 'centos' ]; then
    yum -y install epel-release python3
  fi

}

install_prep() {

  # Create a tmp space that isn't in /tmp
  mkdir /root/installtmp
  TMP=/root/installtmp

}

install_master() {

  # Install the salt master package
  if [ $OS == 'centos' ]; then
    #yum -y install wget salt-common salt-master python36-mysql python36-dateutil python36-m2crypto >> $SETUPLOG 2>&1
    echo ""
    # Create a place for the keys for Ubuntu minions
    #mkdir -p /opt/so/gpg
    #wget --inet4-only -O /opt/so/gpg/SALTSTACK-GPG-KEY.pub https://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest/SALTSTACK-GPG-KEY.pub
    #wget --inet4-only -O /opt/so/gpg/docker.pub https://download.docker.com/linux/ubuntu/gpg
    #wget --inet4-only -O /opt/so/gpg/GPG-KEY-WAZUH https://packages.wazuh.com/key/GPG-KEY-WAZUH

  else
    apt-get install -y salt-common=2019.2.2+ds-1 salt-master=2019.2.2+ds-1 salt-minion=2019.2.2+ds-1
    apt-mark hold salt-common salt-master salt-minion
    echo -e "XXX\n11\nInstalling libssl-dev for M2Crypto... \nXXX"
    apt-get -y install libssl-dev
    echo -e "XXX\n12\nUsing pip3 to install M2Crypto for Salt... \nXXX"
    pip3 install M2Crypto

  fi

  copy_master_config

}

ls_heapsize() {

  # Determine LS Heap Size
  if [ $TOTAL_MEM -ge 32000 ] ; then
      LS_HEAP_SIZE="1000m"
  else
      # If minimal RAM, then set minimal heap
      LS_HEAP_SIZE="500m"
  fi

}

master_pillar() {

  # Create the master pillar
  touch /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "master:" > /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  mainip: $MAINIP" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  mainint: $MAININT" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  esheap: $ES_HEAP_SIZE" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  esclustername: {{ grains.host }}" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  if [ $INSTALLTYPE == 'EVALMODE' ]; then
    echo "  freq: 0" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
    echo "  domainstats: 0" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
    echo "  ls_pipeline_batch_size: 125" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
    echo "  ls_input_threads: 1" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
    echo "  ls_batch_count: 125" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
    echo "  mtu: 1500" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls

  else
    echo "  freq: 0" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
    echo "  domainstats: 0" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  fi
  echo "  lsheap: $LS_HEAP_SIZE" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  lsaccessip: 127.0.0.1" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  elastalert: 1" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  ls_pipeline_workers: $CPUCORES" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  nids_rules: $RULESETUP" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  oinkcode: $OINKCODE" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  #echo "  access_key: $ACCESS_KEY" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  #echo "  access_secret: $ACCESS_SECRET" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  es_port: $NODE_ES_PORT" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  log_size_limit: $LOG_SIZE_LIMIT" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  cur_close_days: $CURCLOSEDAYS" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  #echo "  mysqlpass: $MYSQLPASS" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  #echo "  fleetpass: $FLEETPASS" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  grafana: $GRAFANA" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  osquery: $OSQUERY" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  wazuh: $WAZUH" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  thehive: $THEHIVE" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  echo "  playbook: $PLAYBOOK" >> /opt/so/saltstack/pillar/masters/$MINION_ID.sls
  }

master_static() {

  # Create a static file for global values
  touch /opt/so/saltstack/pillar/static.sls

  echo "static:" > /opt/so/saltstack/pillar/static.sls
  echo "  hnmaster: $HNMASTER" >> /opt/so/saltstack/pillar/static.sls
  echo "  ntpserver: $NTPSERVER" >> /opt/so/saltstack/pillar/static.sls
  echo "  proxy: $PROXY" >> /opt/so/saltstack/pillar/static.sls
  echo "  broversion: $BROVERSION" >> /opt/so/saltstack/pillar/static.sls
  echo "  ids: $NIDS" >> /opt/so/saltstack/pillar/static.sls
  echo "  masterip: $MAINIP" >> /opt/so/saltstack/pillar/static.sls
  echo "  hiveuser: hiveadmin" >> /opt/so/saltstack/pillar/static.sls
  echo "  hivepassword: hivechangeme" >> /opt/so/saltstack/pillar/static.sls
  echo "  hivekey: $HIVEKEY" >> /opt/so/saltstack/pillar/static.sls
  echo "  cortexuser: cortexadmin" >> /opt/so/saltstack/pillar/static.sls
  echo "  cortexpassword: cortexchangeme" >> /opt/so/saltstack/pillar/static.sls
  echo "  cortexkey: $CORTEXKEY" >> /opt/so/saltstack/pillar/static.sls
  echo "  fleetsetup: 0" >> /opt/so/saltstack/pillar/static.sls
  echo "  sensoronikey: $SENSORONIKEY" >> /opt/so/saltstack/pillar/static.sls
  if [[ $MASTERUPDATES == 'MASTER' ]]; then
    echo "  masterupdate: 1" >> /opt/so/saltstack/pillar/static.sls
  else
    echo "  masterupdate: 0" >> /opt/so/saltstack/pillar/static.sls
  fi
}

minio_generate_keys() {

  local charSet="[:graph:]"

  ACCESS_KEY=$(cat /dev/urandom | tr -cd "$charSet" | tr -d \' | tr -d \" | head -c 20)
  ACCESS_SECRET=$(cat /dev/urandom | tr -cd "$charSet" | tr -d \' | tr -d \" | head -c 40)

}

node_pillar() {

  NODEPILLARPATH=$TMP/pillar/nodes
  if [ ! -d $NODEPILLARPATH ]; then
    mkdir -p $NODEPILLARPATH
  fi

  # Create the node pillar
  touch $NODEPILLARPATH/$MINION_ID.sls
  echo "node:" > $NODEPILLARPATH/$MINION_ID.sls
  echo "  mainip: $MAINIP" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  mainint: $MAININT" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  esheap: $NODE_ES_HEAP_SIZE" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  esclustername: {{ grains.host }}" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  lsheap: $NODE_LS_HEAP_SIZE" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  ls_pipeline_workers: $LSPIPELINEWORKERS" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  ls_pipeline_batch_size: $LSPIPELINEBATCH" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  ls_input_threads: $LSINPUTTHREADS" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  ls_batch_count: $LSINPUTBATCHCOUNT" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  es_shard_count: $SHARDCOUNT" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  node_type: $NODETYPE" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  es_port: $NODE_ES_PORT" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  log_size_limit: $LOG_SIZE_LIMIT" >> $NODEPILLARPATH/$MINION_ID.sls
  echo "  cur_close_days: $CURCLOSEDAYS" >> $NODEPILLARPATH/$MINION_ID.sls

}

patch_pillar() {

  case $INSTALLTYPE in
    MASTERONLY | EVALMODE)
      PATCHPILLARPATH=/opt/so/saltstack/pillar/masters
      ;;
    SENSORONLY)
      PATCHPILLARPATH=$SENSORPILLARPATH
      ;;
    STORAGENODE | PARSINGNODE | HOTNODE | WARMNODE)
      PATCHPILLARPATH=$NODEPILLARPATH
      ;;
  esac


  echo "" >> $PATCHPILLARPATH/$MINION_ID.sls
  echo "patch:" >> $PATCHPILLARPATH/$MINION_ID.sls
  echo "  os:" >> $PATCHPILLARPATH/$MINION_ID.sls
  echo "    schedule_name: $PATCHSCHEDULENAME" >> $PATCHPILLARPATH/$MINION_ID.sls
  echo "    enabled: True" >> $PATCHPILLARPATH/$MINION_ID.sls
  echo "    splay: 300" >> $PATCHPILLARPATH/$MINION_ID.sls


}

patch_schedule_os_new() {
  OSPATCHSCHEDULEDIR="$TMP/salt/patch/os/schedules"
  OSPATCHSCHEDULE="$OSPATCHSCHEDULEDIR/$PATCHSCHEDULENAME.yml"

  if [ ! -d $OSPATCHSCHEDULEDIR ] ; then
    mkdir -p $OSPATCHSCHEDULEDIR
  fi

  echo "patch:" > $OSPATCHSCHEDULE
      echo "  os:" >> $OSPATCHSCHEDULE
      echo "    schedule:" >> $OSPATCHSCHEDULE
      for psd in "${PATCHSCHEDULEDAYS[@]}"
      do
        psd=$(echo $psd | sed 's/"//g')
        echo "      - $psd:" >> $OSPATCHSCHEDULE
        for psh in "${PATCHSCHEDULEHOURS[@]}"
        do
          psh=$(echo $psh | sed 's/"//g')
          echo "        - '$psh'" >> $OSPATCHSCHEDULE
        done
      done

}

process_components() {
  CLEAN=${COMPONENTS//\"}
  GRAFANA=0
  OSQUERY=0
  WAZUH=0
  THEHIVE=0
  PLAYBOOK=0

  IFS=$' '
  for item in $(echo "$CLEAN"); do
	  let $item=1
  done
  unset IFS
}

saltify() {

  # Install updates and Salt
  if [ $OS == 'centos' ]; then
    ADDUSER=adduser

    if [ $INSTALLTYPE == 'MASTERONLY' ] || [ $INSTALLTYPE == 'EVALMODE' ]; then
      yum -y install wget https://repo.saltstack.com/py3/redhat/salt-py3-repo-latest-2.el7.noarch.rpm
      cp /etc/yum.repos.d/salt-latest.repo /etc/yum.repos.d/salt-2019-2.repo
      sed -i 's/latest/2019.2/g' /etc/yum.repos.d/salt-2019-2.repo
      # Download Ubuntu Keys in case master updates = 1
      mkdir -p /opt/so/gpg
      wget --inet4-only -O /opt/so/gpg/SALTSTACK-GPG-KEY.pub https://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest/SALTSTACK-GPG-KEY.pub
      wget --inet4-only -O /opt/so/gpg/docker.pub https://download.docker.com/linux/ubuntu/gpg
      wget --inet4-only -O /opt/so/gpg/GPG-KEY-WAZUH https://packages.wazuh.com/key/GPG-KEY-WAZUH
      cat > /etc/yum.repos.d/wazuh.repo <<\EOF
[wazuh_repo]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh repository
baseurl=https://packages.wazuh.com/3.x/yum/
protect=1
EOF

    else

      if [ $MASTERUPDATES == 'MASTER' ]; then

        # Create the GPG Public Key for the Salt Repo
        echo "-----BEGIN PGP PUBLIC KEY BLOCK-----" > /etc/pki/rpm-gpg/saltstack-signing-key
        echo "Version: GnuPG v2.0.22 (GNU/Linux)" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "mQENBFOpvpgBCADkP656H41i8fpplEEB8IeLhugyC2rTEwwSclb8tQNYtUiGdna9" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "m38kb0OS2DDrEdtdQb2hWCnswxaAkUunb2qq18vd3dBvlnI+C4/xu5ksZZkRj+fW" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "tArNR18V+2jkwcG26m8AxIrT+m4M6/bgnSfHTBtT5adNfVcTHqiT1JtCbQcXmwVw" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "WbqS6v/LhcsBE//SHne4uBCK/GHxZHhQ5jz5h+3vWeV4gvxS3Xu6v1IlIpLDwUts" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "kT1DumfynYnnZmWTGc6SYyIFXTPJLtnoWDb9OBdWgZxXfHEcBsKGha+bXO+m2tHA" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "gNneN9i5f8oNxo5njrL8jkCckOpNpng18BKXABEBAAG0MlNhbHRTdGFjayBQYWNr" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "YWdpbmcgVGVhbSA8cGFja2FnaW5nQHNhbHRzdGFjay5jb20+iQE4BBMBAgAiBQJT" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "qb6YAhsDBgsJCAcDAgYVCAIJCgsEFgIDAQIeAQIXgAAKCRAOCKFJ3le/vhkqB/0Q" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "WzELZf4d87WApzolLG+zpsJKtt/ueXL1W1KA7JILhXB1uyvVORt8uA9FjmE083o1" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "yE66wCya7V8hjNn2lkLXboOUd1UTErlRg1GYbIt++VPscTxHxwpjDGxDB1/fiX2o" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "nK5SEpuj4IeIPJVE/uLNAwZyfX8DArLVJ5h8lknwiHlQLGlnOu9ulEAejwAKt9CU" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "4oYTszYM4xrbtjB/fR+mPnYh2fBoQO4d/NQiejIEyd9IEEMd/03AJQBuMux62tjA" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "/NwvQ9eqNgLw9NisFNHRWtP4jhAOsshv1WW+zPzu3ozoO+lLHixUIz7fqRk38q8Q" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "9oNR31KvrkSNrFbA3D89uQENBFOpvpgBCADJ79iH10AfAfpTBEQwa6vzUI3Eltqb" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "9aZ0xbZV8V/8pnuU7rqM7Z+nJgldibFk4gFG2bHCG1C5aEH/FmcOMvTKDhJSFQUx" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "uhgxttMArXm2c22OSy1hpsnVG68G32Nag/QFEJ++3hNnbyGZpHnPiYgej3FrerQJ" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "zv456wIsxRDMvJ1NZQB3twoCqwapC6FJE2hukSdWB5yCYpWlZJXBKzlYz/gwD/Fr" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "GL578WrLhKw3UvnJmlpqQaDKwmV2s7MsoZogC6wkHE92kGPG2GmoRD3ALjmCvN1E" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "PsIsQGnwpcXsRpYVCoW7e2nW4wUf7IkFZ94yOCmUq6WreWI4NggRcFC5ABEBAAGJ" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "AR8EGAECAAkFAlOpvpgCGwwACgkQDgihSd5Xv74/NggA08kEdBkiWWwJZUZEy7cK" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "WWcgjnRuOHd4rPeT+vQbOWGu6x4bxuVf9aTiYkf7ZjVF2lPn97EXOEGFWPZeZbH4" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "vdRFH9jMtP+rrLt6+3c9j0M8SIJYwBL1+CNpEC/BuHj/Ra/cmnG5ZNhYebm76h5f" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "T9iPW9fFww36FzFka4VPlvA4oB7ebBtquFg3sdQNU/MmTVV4jPFWXxh4oRDDR+8N" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "1bcPnbB11b5ary99F/mqr7RgQ+YFF0uKRE3SKa7a+6cIuHEZ7Za+zhPaQlzAOZlx" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "fuBmScum8uQTrEF5+Um5zkwC7EXTdH1co/+/V/fpOtxIg4XO4kcugZefVm5ERfVS" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "MA==" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "=dtMN" >> /etc/pki/rpm-gpg/saltstack-signing-key
        echo "-----END PGP PUBLIC KEY BLOCK-----" >> /etc/pki/rpm-gpg/saltstack-signing-key

        # Add the Wazuh Key
        cat > /etc/pki/rpm-gpg/GPG-KEY-WAZUH <<\EOF
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1

mQINBFeeyYwBEACyf4VwV8c2++J5BmCl6ofLCtSIW3UoVrF4F+P19k/0ngnSfjWb
8pSWB11HjZ3Mr4YQeiD7yY06UZkrCXk+KXDlUjMK3VOY7oNPkqzNaP6+8bDwj4UA
hADMkaXBvWooGizhCoBtDb1bSbHKcAnQ3PTdiuaqF5bcyKk8hv939CHulL2xH+BP
mmTBi+PM83pwvR+VRTOT7QSzf29lW1jD79v4rtXHJs4KCz/amT/nUm/tBpv3q0sT
9M9rH7MTQPdqvzMl122JcZST75GzFJFl0XdSHd5PAh2mV8qYak5NYNnwA41UQVIa
+xqhSu44liSeZWUfRdhrQ/Nb01KV8lLAs11Sz787xkdF4ad25V/Rtg/s4UXt35K3
klGOBwDnzPgHK/OK2PescI5Ve1z4x1C2bkGze+gk/3IcfGJwKZDfKzTtqkZ0MgpN
7RGghjkH4wpFmuswFFZRyV+s7jXYpxAesElDSmPJ0O07O4lQXQMROE+a2OCcm0eF
3+Cr6qxGtOp1oYMOVH0vOLYTpwOkAM12/qm7/fYuVPBQtVpTojjV5GDl2uGq7p0o
h9hyWnLeNRbAha0px6rXcF9wLwU5n7mH75mq5clps3sP1q1/VtP/Fr84Lm7OGke4
9eD+tPNCdRx78RNWzhkdQxHk/b22LCn1v6p1Q0qBco9vw6eawEkz1qwAjQARAQAB
tDFXYXp1aC5jb20gKFdhenVoIFNpZ25pbmcgS2V5KSA8c3VwcG9ydEB3YXp1aC5j
b20+iQI9BBMBCAAnBQJXnsmMAhsDBQkFo5qABQsJCAcDBRUKCQgLBRYCAwEAAh4B
AheAAAoJEJaz7l8pERFFHEsQAIaslejcW2NgjgOZuvn1Bht4JFMbCIPOekg4Z5yF
binRz0wmA7JNaawDHTBYa6L+A2Xneu/LmuRjFRMesqopUukVeGQgHBXbGMzY46eI
rqq/xgvgWzHSbWweiOX0nn+exbEAM5IyW+efkWNz0e8xM1LcxdYZxkVOqFqkp3Wv
J9QUKw6z9ifUOx++G8UO307O3hT2f+x4MUoGZeOF4q1fNy/VyBS2lMg2HF7GWy2y
kjbSe0p2VOFGEZLuu2f5tpPNth9UJiTliZKmgSk/zbKYmSjiVY2eDqNJ4qjuqes0
vhpUaBjA+DgkEWUrUVXG5yfQDzTiYIF84LknjSJBYSLZ4ABsMjNO+GApiFPcih+B
Xc9Kx7E9RNsNTDqvx40y+xmxDOzVIssXeKqwO8r5IdG3K7dkt2Vkc/7oHOpcKwE5
8uASMPiqqMo+t1RVa6Spckp3Zz8REILbotnnVwDIwo2HmgASirMGUcttEJzubaIa
Mv43GKs8RUH9s5NenC02lfZG7D8WQCz5ZH7yEWrt5bCaQRNDXjhsYE17SZ/ToHi3
OpWu050ECWOHdxlXNG3dOWIdFDdBJM7UfUNSSOe2Y5RLsWfwvMFGbfpdlgJcMSDV
X+ienkrtXhBteTu0dwPu6HZTFOjSftvtAo0VIqGQrKMvKelkkdNGdDFLQw2mUDcw
EQj6uQINBFeeyYwBEADD1Y3zW5OrnYZ6ghTd5PXDAMB8Z1ienmnb2IUzLM+i0yE2
TpKSP/XYCTBhFa390rYgFO2lbLDVsiz7Txd94nHrdWXGEQfwrbxsvdlLLWk7iN8l
Fb4B60OfRi3yoR96a/kIPNa0x26+n79LtDuWZ/DTq5JSHztdd9F1sr3h8i5zYmtv
luj99ZorpwYejbBVUm0+gP0ioaXM37uO56UFVQk3po9GaS+GtLnlgoE5volgNYyO
rkeIua4uZVsifREkHCKoLJip6P7S3kTyfrpiSLhouEZ7kV1lbMbFgvHXyjm+/AIx
HIBy+H+e+HNt5gZzTKUJsuBjx44+4jYsOR67EjOdtPOpgiuJXhedzShEO6rbu/O4
wM1rX45ZXDYa2FGblHCQ/VaS0ttFtztk91xwlWvjTR8vGvp5tIfCi+1GixPRQpbN
Y/oq8Kv4A7vB3JlJscJCljvRgaX0gTBzlaF6Gq0FdcWEl5F1zvsWCSc/Fv5WrUPY
5mG0m69YUTeVO6cZS1aiu9Qh3QAT/7NbUuGXIaAxKnu+kkjLSz+nTTlOyvbG7BVF
a6sDmv48Wqicebkc/rCtO4g8lO7KoA2xC/K/6PAxDrLkVyw8WPsAendmezNfHU+V
32pvWoQoQqu8ysoaEYc/j9fN4H3mEBCN3QUJYCugmHP0pu7VtpWwwMUqcGeUVwAR
AQABiQIlBBgBCAAPBQJXnsmMAhsMBQkFo5qAAAoJEJaz7l8pERFFz8IP/jfBxJSB
iOw+uML+C4aeYxuHSdxmSsrJclYjkw7Asha/fm4Kkve00YAW8TGxwH2kgS72ooNJ
1Q7hUxNbVyrJjQDSMkRKwghmrPnUM3UyHmE0dq+G2NhaPdFo8rKifLOPgwaWAfSV
wgMTK86o0kqRbGpXgVIG5eRwv2FcxM3xGfy7sub07J2VEz7Ba6rYQ3NTbPK42AtV
+wRJDXcgS7y6ios4XQtSbIB5f6GI56zVlwfRd3hovV9ZAIJQ6DKM31wD6Kt/pRun
DjwMZu0/82JMoqmxX/00sNdDT1S13guCfl1WhBu7y1ja9MUX5OpUzyEKg5sxme+L
iY2Rhs6CjmbTm8ER4Uj8ydKyVTy8zbumbB6T8IwCAbEMtPxm6pKh/tgLpoJ+Bj0y
AsGjmhV7R6PKZSDXg7/qQI98iC6DtWc9ibC/QuHLcvm3hz40mBgXAemPJygpxGst
mVtU7O3oHw9cIUpkbMuVqSxgPFmSSq5vEYkka1CYeg8bOz6aCTuO5J0GDlLrpjtx
6lyImbZAF/8zKnW19aq5lshT2qJlTQlZRwwDZX5rONhA6T8IEUnUyD4rAIQFwfJ+
gsXa4ojD/tA9NLdiNeyEcNfyX3FZwXWCtVLXflzdRN293FKamcdnMjVRjkCnp7iu
7eO7nMgcRoWddeU+2aJFqCoQtKCp/5EKhFey
=UIVm
-----END PGP PUBLIC KEY BLOCK-----
EOF

        # Proxy is hating on me.. Lets just set it manually
        echo "[salt-latest]" > /etc/yum.repos.d/salt-latest.repo
        echo "name=SaltStack Latest Release Channel for RHEL/Centos \$releasever" >> /etc/yum.repos.d/salt-latest.repo
        echo "baseurl=https://repo.saltstack.com/py3/redhat/7/\$basearch/latest" >> /etc/yum.repos.d/salt-latest.repo
        echo "failovermethod=priority" >> /etc/yum.repos.d/salt-latest.repo
        echo "enabled=1" >> /etc/yum.repos.d/salt-latest.repo
        echo "gpgcheck=1" >> /etc/yum.repos.d/salt-latest.repo
        echo "gpgkey=file:///etc/pki/rpm-gpg/saltstack-signing-key" >> /etc/yum.repos.d/salt-latest.repo

        # Proxy is hating on me.. Lets just set it manually
        echo "[salt-2019.2]" > /etc/yum.repos.d/salt-2019-2.repo
        echo "name=SaltStack Latest Release Channel for RHEL/Centos \$releasever" >> /etc/yum.repos.d/salt-2019-2.repo
        echo "baseurl=https://repo.saltstack.com/py3/redhat/7/\$basearch/2019.2" >> /etc/yum.repos.d/salt-2019-2.repo
        echo "failovermethod=priority" >> /etc/yum.repos.d/salt-2019-2.repo
        echo "enabled=1" >> /etc/yum.repos.d/salt-2019-2.repo
        echo "gpgcheck=1" >> /etc/yum.repos.d/salt-2019-2.repo
        echo "gpgkey=file:///etc/pki/rpm-gpg/saltstack-signing-key" >> /etc/yum.repos.d/salt-2019-2.repo

        cat > /etc/yum.repos.d/wazuh.repo <<\EOF
[wazuh_repo]
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/GPG-KEY-WAZUH
enabled=1
name=Wazuh repository
baseurl=https://packages.wazuh.com/3.x/yum/
protect=1
EOF
      else
        yum -y install https://repo.saltstack.com/py3/redhat/salt-py3-repo-latest-2.el7.noarch.rpm
        cp /etc/yum.repos.d/salt-latest.repo /etc/yum.repos.d/salt-2019-2.repo
        sed -i 's/latest/2019.2/g' /etc/yum.repos.d/salt-2019-2.repo
cat > /etc/yum.repos.d/wazuh.repo <<\EOF
[wazuh_repo]
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/GPG-KEY-WAZUH
enabled=1
name=Wazuh repository
baseurl=https://packages.wazuh.com/3.x/yum/
protect=1
EOF
      fi
    fi

    yum clean expire-cache
    yum -y install epel-release salt-minion-2019.2.2 yum-utils device-mapper-persistent-data lvm2 openssl
    yum -y update exclude=salt*
    systemctl enable salt-minion

    if [ $INSTALLTYPE == 'MASTERONLY' ] || [ $INSTALLTYPE == 'EVALMODE' ]; then
      yum -y install salt-master-2019.2.2 python3 python36-m2crypto salt-minion-2019.2.2 python36-dateutil python36-mysql python36-docker
      systemctl enable salt-master
    else
      yum -y install salt-minion-2019.2.2 python3 python36-m2crypto python36-dateutil python36-docker
    fi
    echo "exclude=salt*" >> /etc/yum.conf

  else
    ADDUSER=useradd
    DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade

    # Add the pre-requisites for installing docker-ce
    apt-get -y install ca-certificates curl software-properties-common apt-transport-https openssl >> $SETUPLOG 2>&1

    # Grab the version from the os-release file
    UVER=$(grep VERSION_ID /etc/os-release | awk -F '[ "]' '{print $2}')

    # Nasty hack but required for now
    if [ $INSTALLTYPE == 'MASTERONLY' ] || [ $INSTALLTYPE == 'EVALMODE' ]; then

      #echo "Using pip3 to install python-dateutil for salt"
      #pip3 install python-dateutil
      # Install the repo for salt
      wget --inet4-only -O - https://repo.saltstack.com/apt/ubuntu/$UVER/amd64/latest/SALTSTACK-GPG-KEY.pub | apt-key add -
      wget --inet4-only -O - https://repo.saltstack.com/apt/ubuntu/$UVER/amd64/2019.2/SALTSTACK-GPG-KEY.pub | apt-key add -
      echo "deb http://repo.saltstack.com/py3/ubuntu/$UVER/amd64/latest xenial main" > /etc/apt/sources.list.d/saltstack.list
      echo "deb http://repo.saltstack.com/py3/ubuntu/$UVER/amd64/2019.2 xenial main" > /etc/apt/sources.list.d/saltstack2019.list

      # Lets get the docker repo added
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

      # Create a place for the keys
      mkdir -p /opt/so/gpg
      wget --inet4-only -O /opt/so/gpg/SALTSTACK-GPG-KEY.pub https://repo.saltstack.com/apt/ubuntu/$UVER/amd64/latest/SALTSTACK-GPG-KEY.pub
      wget --inet4-only -O /opt/so/gpg/docker.pub https://download.docker.com/linux/ubuntu/gpg
      wget --inet4-only -O /opt/so/gpg/GPG-KEY-WAZUH https://packages.wazuh.com/key/GPG-KEY-WAZUH

      # Get key and install wazuh
      curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
      # Add repo
      echo "deb https://packages.wazuh.com/3.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list

      # Initialize the new repos
      apt-get update >> $SETUPLOG 2>&1
      # Need to add python packages here
      apt-get -y install salt-minion=2019.2.2+ds-1 salt-common=2019.2.2+ds-1 python3-dateutil >> $SETUPLOG 2>&1
      apt-mark hold salt-minion salt-common

    else

      # Copy down the gpg keys and install them from the master
      mkdir $TMP/gpg
      scp socore@$MSRV:/opt/so/gpg/* $TMP/gpg
      apt-key add $TMP/gpg/SALTSTACK-GPG-KEY.pub
      apt-key add $TMP/gpg/GPG-KEY-WAZUH
      echo "deb http://repo.saltstack.com/apt/ubuntu/$UVER/amd64/latest xenial main" > /etc/apt/sources.list.d/saltstack.list
      echo "deb https://packages.wazuh.com/3.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
      # Initialize the new repos
      apt-get update >> $SETUPLOG 2>&1
      # Need to add python dateutil here
      apt-get -y install salt-minion=2019.2.2+ds-1 salt-common=2019.2.2+ds-1 >> $SETUPLOG 2>&1
      apt-mark hold salt-minion salt-common

    fi

  fi

}

salt_checkin() {
  # Master State to Fix Mine Usage
  if [ $INSTALLTYPE == 'MASTERONLY' ] || [ $INSTALLTYPE == 'EVALMODE' ]; then
  echo "Building Certificate Authority"
  salt-call state.apply ca >> $SETUPLOG 2>&1
  echo " *** Restarting Salt to fix any SSL errors. ***"
  service salt-master restart >> $SETUPLOG 2>&1
  sleep 5
  service salt-minion restart >> $SETUPLOG 2>&1
  sleep 15
  echo " Applyng a mine hack "
  sudo salt '*' mine.send x509.get_pem_entries glob_path=/etc/pki/ca.crt >> $SETUPLOG 2>&1
  echo " Applying SSL state "
  salt-call state.apply ssl >> $SETUPLOG 2>&1
  echo "Still Working... Hang in there"
  #salt-call state.highstate

  else

  # Run Checkin
  salt-call state.apply ca >> $SETUPLOG 2>&1
  salt-call state.apply ssl >> $SETUPLOG 2>&1
  #salt-call state.highstate >> $SETUPLOG 2>&1

  fi

}

salt_checkin_message() {

  # Warn the user that this might take a while
  echo "####################################################"
  echo "##                                                ##"
  echo "##        Applying and Installing everything      ##"
  echo "##             (This will take a while)           ##"
  echo "##                                                ##"
  echo "####################################################"

}

salt_firstcheckin() {

  #First Checkin
  salt-call state.highstate >> $SETUPLOG 2>&1

}

salt_master_directories() {

  # Create salt paster directories
  mkdir -p /opt/so/saltstack/salt
  mkdir -p /opt/so/saltstack/pillar

  # Copy over the salt code and templates
  cp -R pillar/* /opt/so/saltstack/pillar/
  chmod +x /opt/so/saltstack/pillar/firewall/addfirewall.sh
  chmod +x /opt/so/saltstack/pillar/data/addtotab.sh
  cp -R salt/* /opt/so/saltstack/salt/

}

salt_install_mysql_deps() {

  if [ $OS == 'centos' ]; then
    yum -y install mariadb-devel
  elif [ $OS == 'ubuntu' ]; then
    apt-get -y install libmysqlclient-dev python3-mysqldb
  fi

}

sensor_pillar() {

  SENSORPILLARPATH=$TMP/pillar/sensors
  if [ ! -d $SENSORPILLARPATH ]; then
    mkdir -p $SENSORPILLARPATH
  fi

  # Create the sensor pillar
  touch $SENSORPILLARPATH/$MINION_ID.sls
  echo "sensor:" > $SENSORPILLARPATH/$MINION_ID.sls
  echo "  interface: bond0" >> $SENSORPILLARPATH/$MINION_ID.sls
  echo "  mainip: $MAINIP" >> $SENSORPILLARPATH/$MINION_ID.sls
  echo "  mainint: $MAININT" >> $SENSORPILLARPATH/$MINION_ID.sls
  if [ $NSMSETUP == 'ADVANCED' ]; then
    echo "  bro_pins:" >> $SENSORPILLARPATH/$MINION_ID.sls
    for PIN in $BROPINS; do
      PIN=$(echo $PIN |  cut -d\" -f2)
    echo "    - $PIN" >> $SENSORPILLARPATH/$MINION_ID.sls
    done
    echo "  suripins:" >> $SENSORPILLARPATH/$MINION_ID.sls
    for SPIN in $SURIPINS; do
      SPIN=$(echo $SPIN |  cut -d\" -f2)
    echo "    - $SPIN" >> $SENSORPILLARPATH/$MINION_ID.sls
    done
  else
    echo "  bro_lbprocs: $BASICBRO" >> $SENSORPILLARPATH/$MINION_ID.sls
    echo "  suriprocs: $BASICSURI" >> $SENSORPILLARPATH/$MINION_ID.sls
  fi
  echo "  brobpf:" >> $SENSORPILLARPATH/$MINION_ID.sls
  echo "  pcapbpf:" >> $SENSORPILLARPATH/$MINION_ID.sls
  echo "  nidsbpf:" >> $SENSORPILLARPATH/$MINION_ID.sls
  echo "  master: $MSRV" >> $SENSORPILLARPATH/$MINION_ID.sls
  echo "  mtu: $MTU" >> $SENSORPILLARPATH/$MINION_ID.sls
  if [ $HNSENSOR != 'inherit' ]; then
  echo "  hnsensor: $HNSENSOR" >> $SENSORPILLARPATH/$MINION_ID.sls
  fi
  echo "  access_key: $ACCESS_KEY" >> $SENSORPILLARPATH/$MINION_ID.sls
  echo "  access_secret: $ACCESS_SECRET" >>  $SENSORPILLARPATH/$MINION_ID.sls

}

set_environment_var() {

  echo "Setting environment variable: $1"

  export "$1"
  echo "$1" >> /etc/environment

}

set_hostname() {

  hostnamectl set-hostname --static $HOSTNAME
  echo "127.0.0.1   $HOSTNAME $HOSTNAME.localdomain localhost localhost.localdomain localhost4 localhost4.localdomain" > /etc/hosts
  echo "::1   localhost localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
  echo $HOSTNAME > /etc/hostname
  if [ $INSTALLTYPE != 'MASTERONLY' ] || [ $INSTALLTYPE != 'EVALMODE' ]; then
    if [[ $TESTHOST = *"not found"* ]] || [[ $TESTHOST = *"connection timed out"* ]]; then
      if ! grep -q $MSRVIP /etc/hosts; then
        echo "$MSRVIP   $MSRV" >> /etc/hosts
      fi
    fi
  fi

}

set_initial_firewall_policy() {

  get_main_ip
  if [ $INSTALLTYPE == 'MASTERONLY' ]; then
    printf "  - $MAINIP\n" >> /opt/so/saltstack/pillar/firewall/minions.sls
    printf "  - $MAINIP\n" >> /opt/so/saltstack/pillar/firewall/masterfw.sls
    /opt/so/saltstack/pillar/data/addtotab.sh mastertab $MINION_ID $MAINIP $CPUCORES $RANDOMUID $MAININT $FSROOT $FSNSM
  fi

  if [ $INSTALLTYPE == 'EVALMODE' ]; then
    printf "  - $MAINIP\n" >> /opt/so/saltstack/pillar/firewall/minions.sls
    printf "  - $MAINIP\n" >> /opt/so/saltstack/pillar/firewall/masterfw.sls
    printf "  - $MAINIP\n" >> /opt/so/saltstack/pillar/firewall/forward_nodes.sls
    printf "  - $MAINIP\n" >> /opt/so/saltstack/pillar/firewall/storage_nodes.sls
    /opt/so/saltstack/pillar/data/addtotab.sh evaltab $MINION_ID $MAINIP $CPUCORES $RANDOMUID $MAININT $FSROOT $FSNSM bond0
  fi

  if [ $INSTALLTYPE == 'SENSORONLY' ]; then
    ssh -i /root/.ssh/so.key socore@$MSRV sudo /opt/so/saltstack/pillar/firewall/addfirewall.sh minions $MAINIP
    ssh -i /root/.ssh/so.key socore@$MSRV sudo /opt/so/saltstack/pillar/firewall/addfirewall.sh forward_nodes $MAINIP
    ssh -i /root/.ssh/so.key socore@$MSRV sudo /opt/so/saltstack/pillar/data/addtotab.sh sensorstab $MINION_ID $MAINIP $CPUCORES $RANDOMUID $MAININT $FSROOT $FSNSM bond0
  fi

  if [ $INSTALLTYPE == 'STORAGENODE' ]; then
    ssh -i /root/.ssh/so.key socore@$MSRV sudo /opt/so/saltstack/pillar/firewall/addfirewall.sh minions $MAINIP
    ssh -i /root/.ssh/so.key socore@$MSRV sudo /opt/so/saltstack/pillar/firewall/addfirewall.sh storage_nodes $MAINIP
    ssh -i /root/.ssh/so.key socore@$MSRV sudo /opt/so/saltstack/pillar/data/addtotab.sh nodestab $MINION_ID $MAINIP $CPUCORES $RANDOMUID $MAININT $FSROOT $FSNSM
  fi

  if [ $INSTALLTYPE == 'PARSINGNODE' ]; then
    echo "blah"
  fi

  if [ $INSTALLTYPE == 'HOTNODE' ]; then
    echo "blah"
  fi

  if [ $INSTALLTYPE == 'WARMNODE' ]; then
    echo "blah"
  fi

}

set_node_type() {

  # Determine the node type based on whiplash choice
  if [ $INSTALLTYPE == 'STORAGENODE' ] || [ $INSTALLTYPE == 'EVALMODE' ]; then
    NODETYPE='storage'
  fi
  if [ $INSTALLTYPE == 'PARSINGNODE' ]; then
    NODETYPE='parser'
  fi
  if [ $INSTALLTYPE == 'HOTNODE' ]; then
    NODETYPE='hot'
  fi
  if [ $INSTALLTYPE == 'WARMNODE' ]; then
    NODETYPE='warm'
  fi

}

set_updates() {
  echo "MASTERUPDATES is $MASTERUPDATES"
  if [ $MASTERUPDATES == 'MASTER' ]; then
    if [ $OS == 'centos' ]; then
      if ! grep -q $MSRV /etc/yum.conf; then
      echo "proxy=http://$MSRV:3142" >> /etc/yum.conf
    fi

    else

    # Set it up so the updates roll through the master
    echo "Acquire::http::Proxy \"http://$MSRV:3142\";" > /etc/apt/apt.conf.d/00Proxy
    echo "Acquire::https::Proxy \"http://$MSRV:3142\";" >> /etc/apt/apt.conf.d/00Proxy

  fi
    fi
}

update_sudoers() {

  if ! grep -qE '^socore\ ALL=\(ALL\)\ NOPASSWD:(\/usr\/bin\/salt\-key|\/opt\/so\/saltstack)' /etc/sudoers; then
    # Update Sudoers so that socore can accept keys without a password
    echo "socore ALL=(ALL) NOPASSWD:/usr/bin/salt-key" | sudo tee -a /etc/sudoers
    echo "socore ALL=(ALL) NOPASSWD:/opt/so/saltstack/pillar/firewall/addfirewall.sh" | sudo tee -a /etc/sudoers
    echo "socore ALL=(ALL) NOPASSWD:/opt/so/saltstack/pillar/data/addtotab.sh" | sudo tee -a /etc/sudoers
  else
    echo "User socore already granted sudo privileges"
  fi

}
