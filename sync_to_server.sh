#!/bin/bash
# Data: 2018-10-30
###################

script_name=$(basename ${0})
script_abs_path=$(readlink -f ${script_name})
script_dirname=$(dirname ${script_abs_path})
script_logfile="${script_dirname}/${script_name}.log"
mysql_user="root"
mysql_pass="nX9Mjnxjwf1f6rM="
pre_db="192.168.241.51"
xtrabackup_bin=$(which --skip-alias innobackupex)
back_dir="/home/data/sync_to_pre/$(date +%Y-%m-%d_%H-00-00)"
the_time="date +%Y-%m-%d_%H:%M:%S"
error_ret="2"

function color_echo () {
    if [ $# -ne 2 ];then
        color_echo red "Need to pass two parameters."
        return ${error_ret}
    fi  

    local green="\033[32m"
    local yellow="\033[33m"
    local red="\033[31m"
    local end="\033[0m"
    case $1 in
    green)
        echo -e "`${the_time}` ${green}${2}${end}" | tee -a ${script_logfile}
        ;;  
    yellow)
        echo -e "`${the_time}` ${yellow}${2}${end}" | tee -a ${script_logfile}
        ;;  
    red)
        echo -e "`${the_time}` ${red}${2}${end}" | tee -a ${script_logfile}
        ;;  
    *)  
        echo "`${the_time}` Unknown color." | tee -a ${script_logfile}
        return ${error_ret}
        ;;  
    esac
}

function xtrabackup_db () {
    color_echo yellow "Backing up the database..."
    ${xtrabackup_bin} --user=${mysql_user} --password=${mysql_pass} --no-timestamp ${back_dir} > /dev/null 2>&1
    if [ $? -eq 0 ];then
        color_echo green "Xtrabackup backup database has been completed."        
    else
        color_echo red "Xtrabackup failed to back up the database, please check."
        exit ${error_ret}
    fi
}

function sync_to_pre () {
    color_echo yellow "Copying to remote pre-release server..."
    scp -r ${back_dir} root@${pre_db}:/home/dbbackup/ &> /dev/null
    if [ $? -eq 0 ];then
        color_echo green "Copy completed OK."
        rm -rf ${back_dir}
    else
        color_echo red "Copy failed, please check."
        exit ${error_ret}
    fi
}

xtrabackup_db
sync_to_pre
