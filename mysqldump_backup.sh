#!/bin/bash
##################
source /etc/bashrc
red="\033[31m"
end="\033[0m"
green="\033[32m"
yellow="\033[33m"
the_time=`date +%Y%m%d_%H%M`
the_year=`date +%Y`
month=`date +%m`
base_dbback_dir="/home/data/dbbackup"
dbback_dir="${base_dbback_dir}/${the_year}_${month}"
dbbackup_log="${base_dbback_dir}/dbbackup.log"
#img_dir="/home/wwwroot/default/pluto/Resources/Uploads"
mysqldump_bin="/usr/local/mysql/bin/mysqldump"
mysql_user="root"
mysql_pass="pass"
db_names=$(mysql -u${mysql_user} -p${mysql_pass} -e 'SHOW DATABASES;' | grep -E -v "Database|information_schema|performance_schema|sys$")
mysqldump_method="${mysqldump_bin} -u${mysql_user} -p${mysql_pass} -hlocalhost --default-character-set=utf8 --single-transaction -e --max_allowed_packet=1048576 --net_buffer_length=8192 "
data_center_ip="192.168.2.108"
rsync_backup_mod="on-line_backup_mod_211_53"
#img_rsync_mod="img"
rsync_bin=`which --skip-alias rsync`
rsync_log="${base_dbback_dir}/rsync.log"
day="1"

function echo_mod () {
    if [ $# -ne 1 ] ;then
        echo_mod "${red}echo_mod need 1 args.${end}"
        exit 2
    fi  
    echo -e "$1" | tee -a ${dbbackup_log}
}

function db_backup_method () {
    ####判断备份目录是否存在,并切换至备份目录
    if [ -d ${dbback_dir} ];then
        cd ${dbback_dir}
    else
        mkdir -p ${dbback_dir} && chown -R www.www ${dbback_dir} && cd ${dbback_dir}
    fi

    ####停止slave进程,记录slave status
    mysql -u${mysql_user} -p${mysql_pass} -e 'STOP SLAVE;'
    mysql -u${mysql_user} -p${mysql_pass} -e 'SHOW SLAVE STATUS\G' > ${the_time}_slave_status.txt

    ####备份数据库
    for db_name in $db_names
    do
        db_backup_name="${db_name}_${the_time}.sql"
        db_tgz="${db_backup_name}.tgz"
        $mysqldump_method ${db_name} > ${db_backup_name} 
        res=$?
        if [ $res -eq 0 ];then
            tar -zcvf ${db_tgz} ${db_backup_name} && rm -f ${db_backup_name}
            echo_mod "${green}${the_time}-------${db_name}数据库备份成功${end}"
        else
            echo_mod "${red}${the_time}------${db_name},mysqldump失败，请检查!"
            continue
        fi
    done

    #####备份完成开启slave进程
    mysql -u${mysql_user} -p${mysql_pass} -e 'START SLAVE;'

    #####打包归档
    tar -cf on-line_${the_time}.sql.tar *${the_time}* && rm -f *${the_time}*.txt *${the_time}*.tgz
    echo_mod "${green}${the_time}-------线上数据库已打包完成${end}"
}
function rsync_mod () {
    if [ $# -ne 3 ];then
        echo_mod "rsync_mod need 3 args"
        echo_mod "usage:rsync_mod localpath remoteip rsync_mod_name"
        exit 1
    fi
    #$1本地文件同步路径
    #$2远端IP
    #$3同步项名称
    echo_mod "${yellow}${the_time}>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>${end}"
    ${rsync_bin} -avz --log-file=${dbbackup_log} $1 ${2}::$3 
    RETVAL=$?
    if [ $RETVAL -eq 0 ];then
        echo_mod "${green}${the_time}----------同步到远程服务器${rsync_server}成功${end}"
    else
        echo_mod "${red}${the_time}----------同步到远程服务器${rsync_server}失败${end}"
    fi
    echo >> ${dbbackup_log}
}

function clean_local_dbback () {
    [ -d ${dbback_dir} ] && cd ${dbback_dir} && find . -maxdepth 1 -type f -mmin +1440 -delete
}

clean_local_dbback
db_backup_method
rsync_mod "${base_dbback_dir}/" "${data_center_ip}" "${rsync_backup_mod}"
