#!/bin/bash
# Datetime: 2019-11-05
# Description: docker发布java项目
###############
###脚本参数: $1(项目名称)  $2(项目端口)  $3(启动参数)
###1.首次发布: 从Harbor拉取java基础镜像，启动项目容器，检查容器端口是否UP，启动成功后显示容器状态信息
###2.日常迭代: 构建新的jar包发布到项目目录，直接重启容器即可
###3.项目启动参数修改: 判断容器当前的启动参数与脚本接收到的启动参数是否一致，如果不一致说明项目启动参数已发生变化，需要启动新的容器才能生效
###4.项目映射端口增加: 判断容器当前暴露的端口数和脚本接收到的端口数是否一致，如果不一致说明项目端口已发生改变，需要启动新的容器才能生效
###############
HARBOR_SERVER=harbor-aliyun.51zhaoyou.com
HARBOR_USER=zhaoyou
HARBOR_PASS=Zhaoyouwang1!
DEPLOY_USER=deploy
CONTAINER_NAME=${1}
CONTAINER_PORT=${2}
DOCKER_BIN="sudo $(which --skip-alias docker)"
HOST_VOLUME_PATH=/docker/project/java/${CONTAINER_NAME}/data
CONTAINER_VOLUME_PATH=/data
IMAGE="${HARBOR_SERVER}/ops/jdk-8:latest"
JAVA_BIN=/usr/local/jdk/bin/java
JAR_FILE=/data/jar/${CONTAINER_NAME}.jar
CONFIG_FILE=/data/config/${CONTAINER_NAME}.yml
JAVA_OPTS=${3:-"-Xms256m -Xmx1024m -Dspring.config.location=${CONFIG_FILE}"}
CMD="${JAVA_BIN} ${JAVA_OPTS} -jar ${JAR_FILE}"
CURRENT_JAVA_OPTS=$(${DOCKER_BIN} inspect -f {{.Config.Cmd}} ${CONTAINER_NAME} | sed -r 's@^[^[:space:]]+[[:space:]](.*)[[:space:]]-jar.*@\1@')

####从Harbor服务器拉取基础镜像
function PullImage () {
    ${DOCKER_BIN} login --username=${HARBOR_USER} --password=${HARBOR_PASS} ${HARBOR_SERVER}
    ${DOCKER_BIN} pull ${IMAGE}
    ${DOCKER_BIN} logout ${HARBOR_SERVER}
}

####统计脚本接受到的端口数量
function PortCount () {
    local PORT_COUNT=0
    for PORT in ${CONTAINER_PORT}
    do
        let PORT_COUNT++
    done
    echo ${PORT_COUNT}
}

####统计当前容器的端口数量
function CurrentPortCount () {
    local CURRENT_PORT=$(${DOCKER_BIN} inspect -f {{.Config.ExposedPorts}} ${CONTAINER_NAME})
    local CURRENT_PORT_COUNT=0
    for PORT in ${CURRENT_PORT}
    do
        let CURRENT_PORT_COUNT++
    done
    echo ${CURRENT_PORT_COUNT}
}

####创建容器时需要暴露哪些端口
function ExposePort () {
    for PORT in ${CONTAINER_PORT}
    do
        echo "-p ${PORT}:${PORT}"
    done
}

####启动项目容器
function RunContainer () {
    ${DOCKER_BIN} run -d \
    --hostname ${CONTAINER_NAME} \
    --name ${CONTAINER_NAME} \
    --restart always \
    $(ExposePort) \
    -v ${HOST_VOLUME_PATH}:${CONTAINER_VOLUME_PATH} \
    ${IMAGE} \
    ${CMD} 
}

####重启容器
function RestartContainer () {
    ${DOCKER_BIN} restart ${CONTAINER_NAME} > /dev/null 2>&1
}

####删除容器
function DeleteContainer () {
    ${DOCKER_BIN} ps -a | grep -E "\<${CONTAINER_NAME}$" | awk '{print $1}' | sudo xargs docker stop | sudo xargs docker rm > /dev/null 2>&1
}

####容器启动后，检查项目的端口是否UP
function CheckServiceStatus () {
    local CURRENT_PORT_COUNT=$(CurrentPortCount)
    while [ $(${DOCKER_BIN} exec ${CONTAINER_NAME} netstat -tnlp | grep -E ":[0-9]+" | wc -l) -ne ${CURRENT_PORT_COUNT} ]
    do
        echo "${CONTAINER_NAME}容器端口正在启动,请耐心等待..."
        sleep 3
    done
    echo "${CONTAINER_NAME}发布成功"
}

####显示当前容器状态信息
function ContainerInspect () {
    local STATUS IP VOLUME EXPOSE PID
    STATUS=$(${DOCKER_BIN} inspect -f {{.State.Status}} ${CONTAINER_NAME})
    IP=$(${DOCKER_BIN} inspect -f {{.NetworkSettings.Networks.bridge.IPAddress}} ${CONTAINER_NAME})
    VOLUME=$(${DOCKER_BIN} inspect -f {{.HostConfig.Binds}} ${CONTAINER_NAME} | awk -F"[[]|[]]" '{print $2}')
    EXPOSE=$(${DOCKER_BIN} inspect -f {{.NetworkSettings.Ports}} ${CONTAINER_NAME} | grep -Eo "[0-9]+/tcp")
    PID=$(${DOCKER_BIN} inspect -f {{.State.Pid}} ${CONTAINER_NAME})
    echo "容器状态: ${STATUS}"
    echo "容器IP: ${IP}"
    echo "挂载的数据卷: ${VOLUME}"
    echo "暴露的端口: ${EXPOSE}"
    echo "容器的PID: ${PID}"
}

####脚本入口
function main () {
    sudo chown -R ${DEPLOY_USER}.${DEPLOY_USER} /docker/
    ####判断是否需要拉取基础镜像
    [ `${DOCKER_BIN} images ${IMAGE} | wc -l` -gt 1 ] || PullImage
    ####判断是否是首次发布
    if ! ${DOCKER_BIN} ps -a | grep -q "\<${CONTAINER_NAME}$" ;then
        RunContainer && CheckServiceStatus && ContainerInspect
    ####判断端口是否改变
    elif [ $(PortCount) != $(CurrentPortCount) ] ;then
        echo "检测到${CONTAINER_NAME}项目端口已发生变化, 正在启动新容器..."
        DeleteContainer && RunContainer && CheckServiceStatus && ContainerInspect
    ####判断项目启动参数是否改变
    elif [[ ${JAVA_OPTS} != ${CURRENT_JAVA_OPTS} ]] ;then
        echo "检测到${CONTAINER_NAME}项目启动参数已发生变化, 正在启动新容器..."
        DeleteContainer && RunContainer && CheckServiceStatus && ContainerInspect
    else
        ####日常迭代
        RestartContainer && CheckServiceStatus && ContainerInspect
    fi
}

main
exit $?
