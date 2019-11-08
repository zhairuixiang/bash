#!/bin/bash
# Version: 2.0
# Datetime: 2019-10-08
# Description: 定时清理harbor镜像
HARBOR_SERVER=harbor-aliyun.51zhaoyou.com
USER=admin
PASSWORD=Harbor12345
HARBOR_PATH=/root/harbor
PROJECTS="java"
DOCKER_COMPOSE=/usr/local/bin/docker-compose
LOGFILE="${0}.log"
RESERVE_TAG_NUM=10
SSL=/bin/true

function echo_mod () {
    local yellow="\033[33m"
    local red="\033[31m"
    local end="\033[0m"
    case $1 in
    yellow)
        echo -e "${yellow}${2}${end}" | tee -a ${LOGFILE}
        ;;
    red)
        echo -e "${red}${2}${end}" | tee -a ${LOGFILE}
        ;;
    *)
        echo "${red}Unknown color.${end}" | tee -a ${LOGFILE}
    esac
}

##### 检查HARBOR SERVER端口
function check_harbor_server () {
    local URL=${1}
    curl -I ${URL} > /dev/null 2>&1
    local RETVAL=$?
    if [ ${RETVAL} -ne 0 ] ;then
        echo_mod red "${URL}不可达, 请检查端口是否开启"
        echo "" >> ${LOGFILE}
        exit ${RETVAL}
    fi
}

##### 软删除 harbor tags
function soft_del () {
    ####判断是否配置了ssl证书
    local SSL=${1}
    if ${SSL} ;then
        local HARBOR_SERVER_URL="https://${2}"
    else
        local HARBOR_SERVER_URL="http://${2}"
    fi
    check_harbor_server ${HARBOR_SERVER_URL}

    local PROJECT=${3}
    local RESERVE_TAG_NUM=${4}
    local CURL="curl -s -X GET --header 'Accept: application/json'"
    ####获取项目ID
    local PROJECT_ID=$(${CURL} "${HARBOR_SERVER_URL}/api/projects" -u ${USER}:${PASSWORD} | grep -w -B 2 "${PROJECT}"| grep project_id | awk -F'[:, ]' '{print $7}')
    ####根据项目ID获取所有仓库
    local REPOS=$(${CURL} "${HARBOR_SERVER_URL}/api/repositories?project_id=${PROJECT_ID}" -u ${USER}:${PASSWORD} | grep "name" | awk -F'"' '{print $4}' | awk -F'/' '{print $2}')

    for repo in ${REPOS}
    do
        ####获取仓库下的TAG数量
        local TAG_NUM=$(${CURL} "${HARBOR_SERVER_URL}/api/repositories/${PROJECT}%2F${repo}/tags" -u ${USER}:${PASSWORD} | grep digest | wc -l)
        ####清除多余TAG
        if [ ${TAG_NUM} -gt ${RESERVE_TAG_NUM} ];then
            local CLEAR_TAG_NUM=$[${TAG_NUM}-${RESERVE_TAG_NUM}]
            ####获取多余TAG的时间戳
            local CLEAR_TAG_TIMESTAMP=$(${CURL} "${HARBOR_SERVER_URL}/api/repositories/${PROJECT}%2F${repo}/tags" -u ${USER}:${PASSWORD} | grep created  | awk -F'[ ".]' '{print $9}' | xargs -i date -d "{}" +%s | sort | head -${CLEAR_TAG_NUM})
            for timestamp in ${CLEAR_TAG_TIMESTAMP}
            do
                ####将时间戳转换为日期
                local DATETIME=$(date -d @${timestamp} "+%Y-%m-%dT%H:%M:%S")
                ####根据日期时间得到TAG名称
                local CLEAR_TAG=$(${CURL} "${HARBOR_SERVER_URL}/api/repositories/${PROJECT}%2F${repo}/tags" -u ${USER}:${PASSWORD} | grep -w -B 7 "${DATETIME}" | sed -n '1p' | awk -F'[ ",]' '{print $9}')
                ####删除TAG
                curl -X DELETE --header 'Accept: text/plain' "${HARBOR_SERVER_URL}/api/repositories/${PROJECT}%2F${repo}/tags/${CLEAR_TAG}" -u ${USER}:${PASSWORD}
            done
        else
            local CLEAR_TAG_NUM=0
        fi
        
        if [ ${CLEAR_TAG_NUM} -ne 0 ];then
            FLAG=/bin/true
        else
            FLAG=/bin/false
        fi

        echo_mod yellow "项目: ${PROJECT}"
        echo_mod yellow "仓库: ${repo}"
        echo_mod yellow "TAG数: ${TAG_NUM}"
        echo_mod yellow "已清除的TAG数: ${CLEAR_TAG_NUM}"
        echo_mod yellow "================================="
    done
}

##### 硬删除 harbor tags
function hard_del () {
    cd ${HARBOR_PATH}
    ${DOCKER_COMPOSE} stop
    docker run -it --name gc --rm --volumes-from=registry vmware/registry:2.6.2-photon garbage-collect /etc/registry/config.yml > /dev/null 2>&1
    ${DOCKER_COMPOSE} start
}

function main () {
    echo_mod yellow "DateTime: $(date "+%Y-%m-%d %H:%M:%S")"
    echo_mod yellow "*********************************"
    for PROJECT in ${PROJECTS}
    do
        soft_del ${SSL} ${HARBOR_SERVER} ${PROJECT} ${RESERVE_TAG_NUM}
    done
    echo "" >> ${LOGFILE}

    if ${FLAG} ;then
        hard_del
    fi
}

main
