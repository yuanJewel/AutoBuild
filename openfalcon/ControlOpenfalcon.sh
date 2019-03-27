#!/bin/bash
# ==================
# Description: 监控系统启动脚本
# Created By: 于志远
# Version: 0.1
# Last Modified: 2019-2-14
# ==================

USER="root"
HOMEDIR="/etc/open-falcon"
WORKSPACE="/etc/open-falcon"
BIN="${WORKSPACE}/open-falcon"
DASHBOARDDIR="${WORKSPACE}/dashboard"
DASHBOARDBIN="${DASHBOARDDIR}/control"

# 将非核心模块组合使用
OTHER='hbs nodata aggregator agent gateway api alarm'

# 启动、关闭、重启等基本操作
# 参数1： 执行动作    参数2： 执行对象模块
Start(){
    local action
    local module

    IsModuleRight $2

    action=$1
    module=$2

    if [[ ${module} == all ]];then
        module=''
    fi

    # 根据不同的模块需求执行不同的操作
    if [[ ${module} == 'dashboard' ]];then
        cd ${DASHBOARDDIR}
        ${DASHBOARDBIN} ${action}
    elif [[ ${module} == 'other' ]];then
        cd ${WORKSPACE}
        ${BIN} ${action} ${OTHER}
    else
        cd ${WORKSPACE}
        ${BIN} ${action} ${module}
    fi
}

# 查看版本号
# 参数1： 执行对象模块
Version(){
    local module
    local i

    IsModuleRight $1
    module=$1

    if [[ ${module} == 'dashboard' ]];then
        cd ${DASHBOARDDIR}
        ${DASHBOARDBIN} version

    # other需要遍历查看
    elif [[ ${module} == 'all' ]];then
        for i in ${OTHER} graph judge transfer
        do
            cd ${WORKSPACE}
            echo -en "${i} \t"
            ${i}/bin/falcon-${i} -v
        done

    # other需要遍历查看
    elif [[ ${module} == 'other' ]];then
        for i in ${OTHER} 
        do
            cd ${WORKSPACE}
            echo -en "${i} \t"
            ${i}/bin/falcon-${i} -v
        done

    # 其余的可以一起完成
    else
        cd ${WORKSPACE}
        ${module}/bin/falcon-${module} -v
    fi 
}

# 查看当前服务状态
# 参数1： 执行对象模块
Status(){
    local module

    IsModuleRight $1
    module=$1

    if [[ ${module} == all ]];then
        module=''
    fi

    if [[ ${module} == 'dashboard' ]];then
        cd ${DASHBOARDDIR}
        ${DASHBOARDBIN} status
    elif [[ ${module} == 'other' ]];then
        cd ${WORKSPACE}
        ${BIN} check ${OTHER}
    else
        cd ${WORKSPACE}
        ${BIN} check ${module}
    fi 

}

# 判断模块名是否正确
# 参数1：模块名 
IsModuleRight(){
    local i
    local is_right


    if [[ x$1 == x ]];then
        Usage
        exit 2
    fi

    local module_name
    module_name=$1

    # 判断用户输入的模块名是否异常
    for i in dashboard all graph judge transfer other hbs nodata aggregator agent gateway api alarm
    do
        if [[ ${module_name} == $i ]];then
            is_right=0
            break
        else
            is_right=1
        fi
    done

    if [[ is_right == 1 ]];then
        Usage
        exit 3
    fi
}

#显示脚本用法，退出脚本
Usage()
{
    cat <<EOF

USAGE:
    $0 [COMMAND] [Module ...]
    $0 [FLAGS]
    
选择功能(COMMAND)模式：

    start     启动相关服务
    stop      停止相关服务
    restart   重新启动相关服务
    reload    重新读取相关配置
    status    查看相关服务状态
    version   检测服务版本号

相关模块： dashboard                指代前端界面服务(不能reload)
         all                      指代下面所有模块
         graph judge transfer     指代核心模块
         (other) hbs nodata aggregator agent gateway api alarm   指代所有非核心模块


查看相关(FLAGS)信息：

    
    help         查看帮助信息

范例：
    $0 start agent     启动agent模块
    $0 stop dashboard  关闭dashboard模块

EOF
}

# 主函数
# 参数1： 用户输入的参数1(指代操作)  参数2： 用户输入的参数2(指代模块)
Main(){

    case "$1" in
        start | stop | restart | reload )
            Start $1 $2
            ;;
        version)
            Version $2
            ;;
        status)
            Status $2
            ;;
        help)
            Usage
            ;;
        *)
            Usage
            exit 1
            ;;
    esac
}

Main $@
