#!/bin/bash

## 변수 설정

txtrst='\033[1;37m' # White
txtred='\033[1;31m' # Red
txtylw='\033[1;33m' # Yellow
txtpur='\033[1;35m' # Purple
txtgrn='\033[1;32m' # Green
txtgra='\033[1;30m' # Gray


function pull() {
  echo -e ""
  echo -e ">> Pull Request 🏃♂️ "
  git pull origin master
}

function build(){
  echo -e ""
  echo -e ">> spring build 🏃♂️ "
  ./gradlew clean build -x test


  echo -e ">> process kill "
  pgrep -f java | xargs kill -2

  echo -e ">> application run "
  nohup java -Djava.security.egd=file:/dev/./urandom  -jar build/libs/subway-map-0.0.1-SNAPSHOT.jar 1> application 2>&1 &


  tail -f application

}


echo -e "${txtylw}=======================================${txtrst}"
echo -e "${txtgrn}  << 스크립트 🧐 >>${txtrst}"
echo -e "${txtylw}=======================================${txtrst}"



## 저장소 pull
pull;

## gradle build
build;
