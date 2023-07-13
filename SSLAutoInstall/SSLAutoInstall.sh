#!/bin/bash

#This shell script is used for issue a Let'sEncrypt Cert And installation more conveniently
#This shell script now provides two methods for cert issue
# 1. Standalone Mode: the easiest way to issue certs, but need to keep port open alaways
# 2.DNS API Mode: the most strong method but a little bit complicated, which can help u issue wildcard certs
# No need to keep port open

#No matter what method you adopt, the cert will be auto renewed in 60 days, no need to worry expirations
#For more info, please check acme official document.

#Author: FranzKafka
#Date: 2022-08-18
#Version:0.0.1

#Some constans here
OS_CHECK=''
CERT_DOMAIN=''
CERT_DEFAULT_INSTALL_PATH='/root/cert/'

#Some basic settings here
plain='\033[0m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'

function LOGD() {
     echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
     echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
     echo -e "${green}[INF] $* ${plain}"
}

#Check whether you are root
LOGI "Permission check..."
currentUser=$(whoami)
LOGD "currentUser is $currentUser"
if [ $currentUser != "root" ]; then
     LOGE "$Attention: Please check whether you are root user, please check whether you are root"
     exit 1
the fi

# check OS_CHECK
LOGI "System Type Check..."
if [[ -f /etc/redhat-release ]]; then
     OS_CHECK="centOS_CHECK"
elif cat /etc/issue | grep -Eqi "debian"; then
     OS_CHECK="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
     OS_CHECK="ubuntu"
elif cat /etc/issue | grep -Eqi "centOS_CHECK|red hat|redhat"; then
     OS_CHECK="centos"
elif cat /proc/version | grep -Eqi "debian"; then
     OS_CHECK="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
     OS_CHECK="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
     OS_CHECK="centos"
else
     LOGE "System version not detected, please contact the script author!\n" && exit 1
the fi

#function for user choice
confirm() {
     if [[ $# > 1 ]]; then
         echo && read -p "$1 [default $2]: " temp
         if [[ x"${temp}" == x"" ]]; then
             temp=$2
         the fi
     else
         read -p "$1 [y/n]: " temp
     the fi
     if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
         return 0
     else
         return 1
     the fi
}

#function for user choice
install_acme() {
     cd ~
     LOGI "Starting to install acme script..."
     curl https://get.acme.sh | sh
     if [ $? -ne 0 ]; then
         LOGE "acme installation failed"
         return 1
     else
         LOGI "acme installed successfully"
     the fi
     return 0
}

#function for domain check
domain_valid_check() {
     local domain=""
     read -p "Please enter your domain name:" domain
     LOGD "The domain name you entered is: ${domain}, domain name validation is in progress..."
     #here we need to judge whether there exists cert already
     local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
     if [ ${currentCert} == ${domain} ]; then
         local certInfo=$(~/.acme.sh/acme.sh --list)
         LOGE "Domain name validity verification failed. The current environment already has a corresponding domain name certificate. Repeat application is not allowed. Current certificate details:"
         LOGI "$certInfo"
         exit 1
     else
         LOGI "Certificate validity check passed..."
         CERT_DOMAIN=${domain}
     the fi
}
#function for domain check
install_path_set() {
     cd ~
     local InstallPath=''
     read -p "Please enter the certificate installation path:" InstallPath
     if [[ -n ${InstallPath} ]]; then
         LOGD "The path you entered is: ${InstallPath}"
     else
         InstallPath=${CERT_DEFAULT_INSTALL_PATH}
         LOGI "The input path is empty, the default path will be used: ${CERT_DEFAULT_INSTALL_PATH}"
     the fi

     if [ ! -d "${InstallPath}" ]; then
         mkdir -p "${InstallPath}"
     else
         rm -rf "${InstallPath}"
         mkdir -p "${InstallPath}"
     the fi

     if [ $? -ne 0 ]; then
         LOGE "Failed to set the installation path, please confirm"
         exit 1
     the fi
     CERT_DEFAULT_INSTALL_PATH=${InstallPath}
}

#fucntion for port check
port_check() {
     if [ $# -ne 1 ]; then
         LOGE "Argument error, script exited..."
         exit 1
     the fi
     port_progress=$(lsof -i:$1 | wc -l)
     if [[ ${port_progress} -ne 0 ]]; then
         LOGD "It is detected that the current port is occupied, please change the port or stop the process"
         return 1
     the fi
     return 0
}

#function for cert issue entry
ssl_cert_issue() {
     local method=""
     echo -E ""
     LOGI "This script currently provides two ways to implement certificate signing"
     LOGI "Method 1: acme standalone mode, need to keep the port open"
     LOGI "Method 2: acme DNS API mode, need to provide Cloudflare Global API Key"
     LOGI "If the domain name is a free domain name, it is recommended to use method 1 to apply"
     LOGI "If the domain name is not a free domain name and Cloudflare is used for resolution, use method 2 to apply"
     read -p "Please choose the method you want to use, please enter the number 1 or 2 and press Enter": method
     LOGI "The method you are using is ${method}"

     if [ "${method}" == "1" ]; then
         ssl_cert_issue_standalone
     elif [ "${method}" == "2" ]; then
         ssl_cert_issue_by_cloudflare
     else
         LOGE "Invalid input, please check your input, the script will exit..."
         exit 1
     the fi
}

#method for standalone mode
ssl_cert_issue_standalone() {
     #install acme first
     install_acme
     if [ $? -ne 0 ]; then
         LOGE "Cannot install acme, please check the error log"
         exit 1
     the fi
     #install socat second
     if [[ x"${OS_CHECK}" == x"centos" ]]; then
         yum install socat -y
     else
         apt install socat -y
     the fi
     if [ $? -ne 0 ]; then
         LOGE "Unable to install socat, please check the error log"
         exit 1
     else
         LOGI "socat installed successfully..."
     the fi
     #creat a directory for install cert
     install_path_set
     #domain valid check
     domain_valid_check
     #get needed port here
     local WebPort=80
     read -p "Please enter the port you want to use, if you press Enter, the default port 80 will be used:" WebPort
     if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
         LOGE "The port ${WebPort} you selected is an invalid value, and the default port 80 will be used for application"
         WebPort=80
     the fi
     LOGI "The ${WebPort} port will be used for certificate application, and the port is now being checked. Please ensure that the port is open..."
     #open the port and kill the occupied progress
     port_check ${WebPort}
     if [ $? -ne 0 ]; then
         LOGE "Port detection failed, please ensure that it is not occupied by other programs, the script exits..."
         exit 1
     else
         LOGI "Port detected successfully..."
     the fi

     ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
     ~/.acme.sh/acme.sh --issue -d ${CERT_DOMAIN} --standalone --httpport ${WebPort}
     if [ $? -ne 0 ]; then
         LOGE "Certificate application failed, please refer to the error message for the reason"
         exit 1
     else
         LOGI "Certificate application successful, start installing certificate..."
     the fi
     #install cert
     ~/.acme.sh/acme.sh --installcert -d ${CERT_DOMAIN} --ca-file /root/cert/ca.cer \
     --cert-file /root/cert/${CERT_DOMAIN}.cer --key-file /root/cert/${CERT_DOMAIN}.key \
     --fullchain-file /root/cert/fullchain.cer

     if [ $? -ne 0 ]; then
         LOGE "Certificate installation failed, script exited"
         exit 1
     else
         LOGI "Certificate installed successfully, enable automatic update..."
     the fi
     ~/.acme.sh/acme.sh --upgrade --auto-upgrade
     if [ $? -ne 0 ]; then
         LOGE "Automatic update setup failed, script exited"
         chmod 755 ${CERT_DEFAULT_INSTALL_PATH}
         exit 1
     else
         LOGI "The certificate has been installed and automatic renewal has been enabled, the specific information is as follows"
         ls -lah ${CERT_DEFAULT_INSTALL_PATH}
         chmod 755 ${CERT_DEFAULT_INSTALL_PATH}
     the fi

}

#method for DNS API mode
ssl_cert_issue_by_cloudflare() {
     echo -E ""
     LOGI "This script will use the Acme script to apply for a certificate. When using it, you must ensure:"
     LOGI "1. Know the Cloudflare registered email address"
     LOGI "2. Know Cloudflare Global API Key"
     LOGI "3. The domain name has been resolved to the current server by Cloudflare"
     confirm "I have confirmed the above [y/n]" "y"
     if [ $? -eq 0 ]; then
         install_acme
         if [ $? -ne 0 ]; then
             LOGE "Cannot install acme, please check the error log"
             exit 1
         the fi
         #creat a directory for install cert
         install_path_set
         #Set DNS API
         CF_GlobalKey=""
         CF_AccountEmail=""

         #domain valid check
         domain_valid_check
         LOGD "Please set API key:"
         read -p "Input your key here:" CF_GlobalKey
         LOGD "Your API key is: ${CF_GlobalKey}"
         LOGD "Please set the registered email address:"
         read -p "Input your email here:" CF_AccountEmail
         LOGD "Your registered email address is: ${CF_AccountEmail}"
         ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
         if [ $? -ne 0 ]; then
             LOGE "Failed to change the default CA to Lets'Encrypt, the script exited"
             exit 1
         the fi
         export CF_Key="${CF_GlobalKey}"
         export CF_Email=${CF_AccountEmail}
         ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CERT_DOMAIN} -d *.${CERT_DOMAIN} --log
         if [ $? -ne 0 ]; then
             LOGE "Failed to issue certificate, script exited"
             exit 1
         else
             LOGI "Certificate issued successfully, installing..."
         the fi
         ~/.acme.sh/acme.sh --installcert -d ${CERT_DOMAIN} -d *.${CERT_DOMAIN} --ca-file /root/cert/ca.cer \
         --cert-file /root/cert/${CERT_DOMAIN}.cer --key-file /root/cert/${CERT_DOMAIN}.key \
         --fullchain-file /root/cert/fullchain.cer
         if [ $? -ne 0 ]; then
             LOGE "Certificate installation failed, script exited"
             exit 1
         else
             LOGI "Certificate installed successfully, enable automatic update..."
         the fi
         ~/.acme.sh/acme.sh --upgrade --auto-upgrade
         if [ $? -ne 0 ]; then
             LOGE "Automatic update setup failed, script exited"
             ls -lah cert
             chmod 755 ${CERT_DEFAULT_INSTALL_PATH}
             exit 1
         else
             LOGI "The certificate has been installed and automatic renewal has been enabled, the specific information is as follows"
             ls -lah ${CERT_DEFAULT_INSTALL_PATH}
             chmod 755 ${CERT_DEFAULT_INSTALL_PATH}
         the fi
     else
         LOGI "Script exited..."
         exit 1
     the fi
}

ssl_cert_issue
