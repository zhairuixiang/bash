#!/bin/bash
# Data: 2018-10-30
##################

#####全局变量定义
script_name=$(basename ${0})
script_abs_path=$(readlink -f ${script_name})
script_dirname=$(dirname ${script_abs_path})
script_logfile="${script_dirname}/${script_name}.log"
xtrabackup_bin=$(which --skip-alias innobackupex)
back_base_dir="/home/dbbackup"
back_dir_name=$(ls ${back_base_dir})
back_dir=${back_base_dir}/${back_dir_name}
data_dir="/usr/local/mysql/var"
mysql_table="/srv/mysql_$(date +%Y-%m-%d_%H-00-00).sql"
mysql_user="root"
mysql_pass="pass"
online_mysql_pass="pass"
the_time="date +%Y-%m-%d_%H:%M:%S"
error_ret="2"

#####邮件通告
function notify () {
    #/usr/local/bin/sendEmail 命令主程序 
    #-f from@163.com 发件人邮箱 
    #-t to@163.com 收件人邮箱 
    #-s smtp.163.com 发件人邮箱的smtp服务器 
    #-u "我是邮件主题" 邮件的标题 
    #-o message-content-type=html 邮件内容的格式,html表示它是html格式 
    #-o message-charset=utf8 邮件内容编码 
    #-xu from@163.com 发件人邮箱的用户名 
    #-xp 123456 发件人邮箱密码 
    #-m "我是邮件内容" 邮件的具体内容
    if [[ ${1} == "OK" ]];then
        state="<font color="\#00FF00"><b>${1}</b></font>"
    else
        state="<font color="\#FF0000"><b>${1}</b></font>"
    fi
    local sendEmail_bin Send_email Send_pass Sendto smtp_server Email_subject Email_body prd_db_ip pre_db_ip
    sendEmail_bin="/usr/local/bin/sendEmail"
    Send_email="zabbixserver@51zhaoyou.com"
    Send_pass="Administrator2!"
    Sendto="zhairuixiang@51zhaoyou.com,chenlonghua@51zhaoyou.com,zhanglin@51zhaoyou.com"
    #Sendto="zhairuixiang@51zhaoyou.com"
    smtp_server="smtp.exmail.qq.com"
    Email_subject="Synchronize online database to pre-release"
    prd_db_ip="192.168.2.137"
    pre_db_ip="192.168.241.51"
    Email_body="线上数据库: <font color="\#000000"><b>${prd_db_ip}</b></font><br/>预发数据库: <font color="\#000000"><b>${pre_db_ip}</b></font><br/>同步状态: ${state}"
    ${sendEmail_bin} -f ${Send_email} -t "${Sendto}" -s ${smtp_server} -u "${Email_subject}" -o message-content-type=html -o message-charset=utf8 -xu ${Send_email} -xp ${Send_pass} -m "${Email_body}"
}

#####自定义颜色输出
function color_echo () {
    if [ $# -ne 2 ];then
        color_echo red "Need to pass two parameters."
        return ${error_ret}
    fi  

    local green yellow red end
    green="\033[32m"
    yellow="\033[33m"
    red="\033[31m"
    end="\033[0m"
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

#####脚本预先检查
function script_pre_check () {
    if ! which --skip-alias innobackupex > /dev/null 2>&1; then
        color_echo red "Not installed xtrabackup, pelease check."
        exit ${error_ret}
    fi

    if [ -z ${back_dir_name} ] ;then 
        color_echo red "Backed up data not found, please check."
        exit ${error_ret}
    fi
}

#####事先备份mysql表
function back_mysql_table () {
    if mysqldump -u${mysql_user} -p${mysql_pass} mysql > ${mysql_table} 2> /dev/null ;then
        color_echo green "mysql table backup succeeded."
    else
        color_echo red "mysql table backup failed, please check."
        return ${error_ret}
    fi
}

#####准备一个完整备份，并备份当前数据
function ready_to_recover () {
    color_echo yellow "Preparing a full backup..."
    if ${xtrabackup_bin} --apply-log ${back_dir} > /dev/null 2>&1 ;then
        color_echo green "completed OK."
        if /etc/init.d/mysql stop &> /dev/null ;then
            color_echo green "Shutting down MySQL. SUCCESS!"
            [ -d ${data_dir} ] && cd ${data_dir} && rm -rf *
        else
            color_echo red "Shutting down MySQL. FAILED!"
            return ${error_ret}
        fi
    else
        color_echo red "failed, please check."
        return ${error_ret}
    fi
}

#####恢复数据并验证
function recover () {
    color_echo yellow "Recovering data..."
    if ${xtrabackup_bin} --copy-back ${back_dir} > /dev/null 2>&1 ;then
        color_echo green "Successful data recovery."
        chown -R mysql.mysql /usr/local/mysql
        cd ${data_dir} && rm -f ib_logfile*    
        if /etc/init.d/mysql start &> /dev/null ;then
            if mysql -u${mysql_user} -p${online_mysql_pass} mysql < ${mysql_table} ;then
                color_echo green "Import mysql database to complete."
            else
                color_echo red "Importing mysql database failed, please check."
                return ${error_ret}
            fi

            if /etc/init.d/mysql restart &> /dev/null ;then
                color_echo green "Restarting MySQL. SUCCESS!"
                rm -rf ${back_dir}
                mysql -u${mysql_user} -p${mysql_pass} -e 'SHOW DATABASES;' &> /dev/null
            else
                color_echo red "Restarting MySQL. FAILED!"
                return ${error_ret}
            fi
        else
            color_echo red "Starting MySQL. FAILED!"
            return ${error_ret}
        fi
    else
        color_echo red "Recovery data failed, please check."
        return ${error_ret}
    fi
}

#####主程序
function main () {
    script_pre_check
    back_mysql_table || return ${error_ret}
    ready_to_recover || return ${error_ret}
    recover || return ${error_ret}
}

main && notify "OK" || notify "Failed, please check."
