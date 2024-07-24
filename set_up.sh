코드 복사
#!/bin/bash

# .profile 파일에 환경 변수 추가
echo 'HISTTIMEFORMAT="%F %T -- "' >> ~/.profile
echo 'export HISTTIMEFORMAT' >> ~/.profile
echo 'export TMOUT=1200' >> ~/.profile

# .profile 파일을 적용
source ~/.profile

# 환경 변수 출력
env

# .bashrc 파일에 환경 변수 추가
echo 'tty=`tty | awk -F"/dev/" '"'"'{print $2}'"'"'`' >> ~/.bashrc
echo 'IP=`w | grep "$tty" | awk '"'"'{print $3}'"'"'`' >> ~/.bashrc
echo 'export PROMPT_COMMAND='"'"'logger -p local0.debug "[USER]$(whoami) [IP]$IP [PID]$$ [PWD]`pwd` [COMMAND] $(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//" )"'"'" >> ~/.bashrc

# .bashrc 파일을 적용
source ~/.bashrc

# /etc/rsyslog.d/50-default.conf 파일에 로컬 로그 설정 추가
echo 'local0.*                        /var/log/command.log' | sudo tee -a /etc/rsyslog.d/50-default.conf

# rsyslog 서비스를 재시작
sudo service rsyslog restart

# 패키지 목록 업데이트
sudo apt update -y

# JDK 1.8 (Java 8) 설치
sudo apt install -y openjdk-8-jdk
