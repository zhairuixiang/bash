#!/bin/bash
# Datetime: 2019-03-10
# Description: 批量修改服务器root密码
####全局变量
script_name=${0}
script_abs_path=$(readlink -f ${script_name})
script_dirname=$(dirname ${script_abs_path})
script_logfile="${script_dirname}/${script_name}.log"
ansible_inventory=$(readlink -f ${1})
password_file="${script_dirname}/passwd_$(date +%Y-%m-%d_%H-%M-%M).csv"
the_time="date +%Y-%m-%d_%H:%M:%S"
error_ret="2"

#####自定义颜色输出
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

####脚本预先检查
function script_pre_check () {
    if [ $# -ne 1 ];then
        color_echo red "Script parameter error. exit...."
        exit ${error_ret}
    fi

    if [ ! -f $1 ];then
        color_echo red "$1 file does not exist."
        exit ${error_ret}
    fi

    if [ ! -s $1 ];then
        color_echo red "$1 file is empty."
        exit ${error_ret}
    fi

    if ! which --skip-alias ansible > /dev/null 2>&1; then
        color_echo red "Not installed ansible. pelease check"
        exit ${error_ret}
    fi
}

####更新服务器密码
function change_root_password () {
    local hostfile=$1
    echo "Account,Login Name,Password,Web Site,Comments" > ${password_file}
    while read ip
    do
        ######判断此主机是否存活
        if ! ping -c 2 ${ip} > /dev/null 2>&1 ;then
            color_echo red "Host ${ip} unachievable, skip, pease check."
            continue
        fi
        ####生成随机字符串密码
        local user="root"
        local random_password=$(openssl rand -base64 32 | head -c 15)
        #local random_password="51zhaoyou1!"
        #####更新root密码
        ansible -i ${ansible_inventory} ${ip} -b -m shell -a "echo ${random_password} | passwd --stdin ${user}" > /dev/null 2>&1
        if [ $? -eq 0 ] ;then
            color_echo green "Host ${ip} root password updated successfully."
            echo "${ip},${user},${random_password},," >> ${password_file}
        else
            color_echo red "Host ${ip} root password updated failed, skip, please check."
            continue
        fi
    done < ${hostfile}
    color_echo yellow "All host passwords have been updated successfully."
    color_echo yellow "PasswordFile: ${password_file}"
    color_echo yellow "LogFile: ${script_logfile}"
    echo >> ${script_logfile}
}

####主程序
function main () {
    script_pre_check $*
    change_root_password ${1}
}

main $*
exit $?
