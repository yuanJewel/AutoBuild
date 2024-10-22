AutoBuild
===
#### writer email adress: luyu151111@163.com

自动化完成系统部署与创建，只需要一个控制机，即可将机房从裸机自动部署至只可以上线使用的环境

自动部署的服务中，包括nginx、tomcat两个网页机制，支持不同语言的网页程序

还可以根据需要自动部署mysql数据库服务，并支持自动完成主从同步的部署

最大的亮点是可以自动化部署Openfalcon，并自动监控。

## Useage

### 快速部署
修改`main.conf`文件中的内容，然后运行`./configure start`

如果不需要PXE装机步骤，在修改了`main.conf`，后运行`./configure skip`

### 小白部署

直接运行`./configure`，进入交互界面，根据提示一个一个完成一些具体参数的设定，
然后自动进行安装部署的操作。

## Parameter

控制服务器一般是运行该程序的机器，可以理解为本机

| 参数名 | 参数含义 | 默认值 |
|:------------- |:---------------:| :---------------:|
| IP | 控制服务器的IPv4地址 | 192.168.4.150 |
| subnet | 控制服务器所在网段 | 192.168.4.0 |
| netmask | 控制服务器的子网掩码 | 255.255.255.0 |
| range_start | 设定PXE装机的服务器的IP地址起始位置 | 192.168.4.200 |
| range_stop | 设定PXE装机的服务器的IP地址终止位置 | 192.168.4.240 |
| isoPath | 控制服务器的iso镜像文件挂载位置 | /var/iso_dvd |
| startRsync | 是否启动nginx多服务器同步 | 0:不启动 、 1:启动 |
| cpunum | 设定服务器的cpu个数 | 4 |
| startMasterslave | 是否启动数据库的主从同步 | 0:不启动 、 1:启动 |
| nginx_server | 设定nginx服务器的个数 | 0 |
| tomcat_server | 设定tomcat服务器的个数 | 0 |
| cache_server | 设定缓存服务器是否部署 | 0:不启动 、 1:启动 |
| mysql_server | 设定mysql服务器的个数 | 0 |
| falcon_server | 设定open-falcon服务是否部署 | 0:不启动 、 1:启动 |

## Lime Light

1. 如果实际服务器个数不足，会报错退出，如果实际服务器超出，则只会将没有分配到服务的服务器完成pxe装机而已
2. 运行是基于从裸机开始部署，所以最好完整使用，防止运行出现
