#!/bin/bash

RED='\033[0;31m'
BROWN='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_ELN="base_eln/"
REVERSE_PROXY="chemotion_reverse_proxy/"
IP="192.168.0.255" # change '255' accoringly with your broadcast iP address

Logo(){
  echo "-------------------------------"
  printf "  ${BROWN}<<< Docker_ELN utility >>>${NC}\n"
  echo "-------------------------------"
}

help() {
  Logo
  echo
  printf "usage: $0 create_elns [N] #where N is any integer number\n\n"
  echo "-----------------------------------------------------------"
  echo " -  help:"
  echo " -  generate_base_eln:"
  echo " -  create_elns:"
  echo " -  start_elns:"
  echo " -  stop_elns:"
  echo " -  add_ip_map:"
  echo " -  remove_ip_map:"
  echo "-----------------------------------------------------------"
}

init() {
  printf "${BLUE}initializing base eln${NC}\n"
  mkdir -p $BASE_ELN
  cd $BASE_ELN
  curl -L -O https://raw.githubusercontent.com/ptrxyz/chemotion/v1.0.3D0.1/client-chemotion/docker-compose.yml
  curl -L -O https://raw.githubusercontent.com/ptrxyz/chemotion/v1.0.3D0.1/client-chemotion/backup.sh
  curl -L -O https://raw.githubusercontent.com/ptrxyz/chemotion/v1.0.3D0.1/client-chemotion/setup.sh
  curl -L -O https://raw.githubusercontent.com/ptrxyz/chemotion/v1.0.3D0.1/client-chemotion/upgrade.sh

  bash ./setup.sh
  docker-compose run eln landscape deploy
  docker-compose run eln init

  sudo sed -i "s/4000:4000/port_number:4000/g"   "docker-compose.yml"
  sudo sed -i "s/worker:/worker_name:/g"         "docker-compose.yml"
  sudo sed -i "s/eln:/eln_name:/g"               "docker-compose.yml"
  cd ..
  mkdir -p $REVERSE_PROXY
  cd $REVERSE_PROXY
  sudo curl -L -O https://raw.githubusercontent.com/mehmood86/chemotion-reverse-proxy/main/Dockerfile
  sudo curl -L -O https://raw.githubusercontent.com/mehmood86/chemotion-reverse-proxy/main/docker-compose.yml
  sudo curl -L -O https://raw.githubusercontent.com/ptrxyz/chemotion/v1.0.3D0.1/reverse-proxy/nginx-passenger.conf
  sudo curl -L -O https://raw.githubusercontent.com/ptrxyz/chemotion/v1.0.3D0.1/reverse-proxy/nginx.conf
  sudo mv nginx-passenger.conf config.txt
  cd ..
}

# create multiple instances of chemotion eln
create_elns() {
  re='^[0-9]+$'
  if ! [[ $1 =~ $re ]]; then
  printf "${RED}Error: Not a valid number ${NC}\n" >&2;
  echo "Hint: $0 create_elns 2";  exit 1
  fi
  echo "creating $1 chemotion ELN instances";

  for number in $(seq 1 $1)
  do
    printf "${BLUE}-- creating directory eln$number ${NC}\n"
    mkdir -p eln$number
    sudo rsync -av $BASE_ELN eln$number
    sudo sed -i "s/port_number:4000/400$number:4000/g" 	"eln$number/docker-compose.yml"
    sudo sed -i "s/worker_name:/worker$number:/g" 	"eln$number/docker-compose.yml"
    sudo sed -i "s/eln_name:/eln$number:/g" 		"eln$number/docker-compose.yml"
    sudo rm eln$number/nginx.conf
    sudo rm eln$number/nginx-passenger.conf
  done

  cd $REVERSE_PROXY
  echo "" > nginx-passenger.conf
  for id in $(seq 1 $1)
  do
    printf "${BLUE} adding configuration for eln$id ${NC}\n"
    sudo sed "s/server_name _;/server_name instance$id.chem.de;/g" config.txt > temp.txt
    sudo sed "s/proxy_pass http:\/\/eln:4000;/proxy_pass http:\/\/$IP:400$id\/;/g" temp.txt >> nginx-passenger.conf
  done
  rm temp.txt
}

start_elns() {
  re='^[0-9]+$'
  if ! [[ $1 =~ $re ]]; then
  printf "${RED}Error: Not a valid number${NC}\n" >&2;
  echo "Hint: $0 start_elns 2"; exit 1
  fi

  prinft "${BLUE}Starting NGINX Reverse Proxy server${NC}"
  docker-compose -f chemotion_reverse_proxy/docker-compose.yml up -d

  for number in $(seq 1 $1); do
    if [ -d "eln$number" ]; then
      # map IP in /etc/hosts
      echo "Mapping IP for instance$number.chem.de"
      sudo sh -c "echo $IP instance$number.chem.de >> /etc/hosts"
      
      printf "${BLUE}eln$number exists, starting contianer...${NC}\n"
      docker-compose -f eln$number/docker-compose.yml up -d
    else
      printf "${RED}Error: eln$number not found, no services for eln$number started.${NC}\n"
      exit 1
    fi
  done
}

stop_elns() {
  re='^[0-9]+$'
  if ! [[ $1 =~ $re ]]; then
  printf "${RED}Error: not a valid number${NC}\n" >&2
  echo "Hint: $0 stop_elns 2"; exit 1
  fi

  printf "${BLUE}Stopping NGINX Reverse Proxy server${NC}"
  docker-compose -f chemotion_reverse_proxy/docker-compose.yml down

  for number in $(seq 1 $1); do
    if [ -d "eln$number" ]; then
      # Remove IP map in /etc/hosts 
      echo "Removing IP for instance$number.chem.de"
      sudo sed -i "/$IP instance$number.chem.de/d" /etc/hosts

      printf "${BLUE}eln$number exists, stopping contianer...${NC}\n"
      docker-compose -f eln$number/docker-compose.yml down
    else
      printf "${RED}Error: eln$number not found, Aborting...${NC}\n"
      exit 1
    fi
  done
}

add_ip_map() {
  re='^[0-9]+$'
  if ! [[ $1 =~ $re ]]; then
    printf "${RED}Error: Not a valid number ${NC}\n" >&2;
    echo "Hint: $0 add_ip_map 2";  exit 1
  fi

  sudo sed -i "/# Chemotion ELN/d" /etc/hosts
  sudo sh -c "echo '\n#Chemotion ELN' >> hosts"
  for id in $(seq 1 $1)
  do
    echo "Mapping IP for instance$id.chem.de"
    sudo sh -c "echo $IP instance$id.chem.de >> /etc/hosts"
  done
}

remove_ip_map(){
  re='^[0-9]+$'
  if ! [[ $1 =~ $re ]]; then
    printf "${RED}Error: Not a valid number ${NC}\n" >&2;
    echo "Hint: $0 remove_ip_map 2";  exit 1
  fi
  
  sudo sed -i "/# Chemotion ELN/d" /etc/hosts
  for id in $(seq 1 $1)
  do 
    echo "Removing IP for instance$id.chem.de"
    sudo sed -i "/$IP instance$id.chem.de/d" /etc/hosts
  done 
}


# Check if a function exists in the script
if declare -f "$1" > /dev/null
then 
  "$@"
else
  printf "${RED}'$1'${NC} is not a valid function\n" >&2
  printf "For help try: ${BROWN}$0 help\n"
  exit 1
fi

FunctionalTesting(){
  printf "${BROWN}Selenium Test Framework ::: starting functional testing...${NC}"
  echo 

  while ! curl http://localhost:4000/
  do 
    echo "$(date) - still trying"
    sleep 1
  done
  echo "$(date) - connected successfully"
  sleep 1
  echo "Chemotion ELN instance is running"
 
  secs=$((5))
  while [ $secs -gt 0 ]; do
     echo -ne "starting SeleniumTests in: $secs\033[0K\r"
     sleep 1
     : $((secs--))
  done
  echo ""
  echo
  echo "run test 1:: URL='https://127.0.0.1:4000' python3 [path/to/test/directory/] "
  echo "run test 2:: "
  echo "run test 3:: "
}
