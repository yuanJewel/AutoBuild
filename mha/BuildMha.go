package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"golang.org/x/crypto/ssh"
	"io"
	"io/ioutil"
	"log"
	"net"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

var installUrl = "http://120.92.156.238:8888/mha/"
var mhaConfigDir = "/work/config/mha/"
var mhaConfigFile = "mha.conf"

// 获取变量值
var (
	mip string
	sip string
	cip string
	vip string
)

var master_complete chan int = make(chan int)
var candicate_complete chan int = make(chan int)
var slave_complete chan int = make(chan int)

func connect(user, password, host, key string, port int, cipherList []string) (*ssh.Session, error) {
	var (
		auth         []ssh.AuthMethod
		addr         string
		clientConfig *ssh.ClientConfig
		client       *ssh.Client
		config       ssh.Config
		session      *ssh.Session
		err          error
	)
	// get auth method , 用秘钥或者密码连接
	auth = make([]ssh.AuthMethod, 0)
	if key == "" {
		auth = append(auth, ssh.Password(password))
	} else {
		pemBytes, err := ioutil.ReadFile(key)
		if err != nil {
			return nil, err
		}

		var signer ssh.Signer
		if password == "" {
			signer, err = ssh.ParsePrivateKey(pemBytes)
		} else {
			signer, err = ssh.ParsePrivateKeyWithPassphrase(pemBytes, []byte(password))
		}
		if err != nil {
			return nil, err
		}
		auth = append(auth, ssh.PublicKeys(signer))
	}

	if len(cipherList) == 0 {
		config = ssh.Config{
			Ciphers: []string{"aes128-ctr", "aes192-ctr",
				"aes256-ctr", "aes128-gcm@openssh.com", "arcfour256",
				"arcfour128", "aes128-cbc", "3des-cbc", "aes192-cbc", "aes256-cbc"},
		}
	} else {
		config = ssh.Config{
			Ciphers: cipherList,
		}
	}

	clientConfig = &ssh.ClientConfig{
		User:    user,
		Auth:    auth,
		Timeout: 30 * time.Second,
		Config:  config,
		HostKeyCallback: func(hostname string, remote net.Addr, key ssh.PublicKey) error {
			return nil
		},
	}

	// ssh 连接
	addr = fmt.Sprintf("%s:%d", host, port)

	if client, err = ssh.Dial("tcp", addr, clientConfig); err != nil {
		return nil, err
	}

	// create session
	if session, err = client.NewSession(); err != nil {
		return nil, err
	}

	modes := ssh.TerminalModes{
		ssh.ECHO:          0,     // disable echoing
		ssh.TTY_OP_ISPEED: 14400, // input speed = 14.4kbaud
		ssh.TTY_OP_OSPEED: 14400, // output speed = 14.4kbaud
	}

	if err := session.RequestPty("xterm", 80, 40, modes); err != nil {
		return nil, err
	}

	return session, nil
}

const (
	username = "root"
	password = ""
	key      = "/root/.ssh/id_rsa"
	port     = 22
)

func sshDoShell(ip string, cmd string) error {
	ciphers := []string{}
	session, err := connect(username, password, ip, key, port, ciphers)

	if err != nil {
		fmt.Println("连接 ", ip, " 异常")
		log.Panic(err)
	}

	defer func() {
		_ = session.Close()
	}()

	session.Stdout = os.Stdout
	session.Stderr = os.Stderr

	err = session.Run(cmd)
	if err != nil {
		return errors.New(err.Error())
	}

	return nil
}

func buildMaster() {

	// 检查keepalived是否安装
	check := "systemctl status keepalived"

	err := sshDoShell(mip, check)
	if err == nil {
		fmt.Println("keepalived has been installed")
	} else {
		// 安装并配置keepalived
		var bm_cip string
		for _, f_ip := range strings.Split(cip, ",") {
			bm_cip = bm_cip + "\\        " + f_ip + "\\n"
		}

		cmd := "/usr/bin/yum install -y keepalived ; " +
			"/usr/bin/wget " + installUrl + "keepalived.conf -O /etc/keepalived/keepalived.conf ; " +
			"/usr/bin/sed -i 's/mip/" + mip + "/' /etc/keepalived/keepalived.conf ; " +
			"/usr/bin/sed -i 's/BACKUP/MASTER/' /etc/keepalived/keepalived.conf ;" +
			"/usr/bin/sed -i 's/vip/" + vip + "/' /etc/keepalived/keepalived.conf ; " +
			"/usr/bin/sed -i 's/oip/" + bm_cip + "/' /etc/keepalived/keepalived.conf ; " +
			"/usr/bin/systemctl restart keepalived"

		if err := sshDoShell(mip, cmd); err != nil {
			log.Panic(err)
		}
	}

	cmd := "yum install -y epel-release ;" +
		"yum install -y http://120.92.156.238:8888/mha/mha4mysql-node.rpm ;" +
		"ln -s /work/servers/mysql/bin/mysqlbinlog /usr/local/bin/mysqlbinlog;" +
		"ln -s /work/servers/mysql/bin/mysql /usr/local/bin/mysql"

	if err := sshDoShell(mip, cmd); err != nil {
		fmt.Printf("\n %c[1;40;33m%s%c[0m\n\n", 0x1B, "master's mysql and mysqlbinlog are exist", 0x1B)
	}

	fmt.Printf("\n %c[1;40;32m%s%c[0m\n\n", 0x1B, "master keepalived is ready", 0x1B)
	master_complete <- 0
}

func buildCandicate() {
	var slave_complete chan int = make(chan int)
	priority := 100

	// 给每个从服务器配置
	for _, ip := range strings.Split(cip, ",") {
		priority -= 10
		go func(f_ip string) {
			// 检查keepalived是否安装
			check := "systemctl status keepalived"
			err := sshDoShell(f_ip, check)
			if err == nil {
				fmt.Println("keepalived has been installed")
			} else {
				bs_cip := ""
				for _, bs_ip := range strings.Split(cip, ",") {
					if bs_ip != f_ip {
						bs_cip = bs_cip + "\\        " + bs_ip + "\\n"
					}
				}
				bs_cip = bs_cip + "\\        " + mip + "\\n"

				cmd := "/usr/bin/yum install -y keepalived ; " +
					"/usr/bin/wget " + installUrl + "keepalived.conf -O /etc/keepalived/keepalived.conf ; " +
					"/usr/bin/sed -i 's/mip/" + f_ip + "/' /etc/keepalived/keepalived.conf ; " +
					"/usr/bin/sed -i 's/vip/" + vip + "/' /etc/keepalived/keepalived.conf ; " +
					"/usr/bin/sed -i 's/100/" + strconv.Itoa(priority) + "/' /etc/keepalived/keepalived.conf ; " +
					"/usr/bin/sed -i 's/oip/" + bs_cip + "/' /etc/keepalived/keepalived.conf ; " +
					"/usr/bin/systemctl restart keepalived"

				if err := sshDoShell(f_ip, cmd); err != nil {
					log.Panic(err)
				}
			}
			cmd := "yum install -y epel-release ;" +
				"yum install -y http://120.92.156.238:8888/mha/mha4mysql-node.rpm ;" +
				"ln -s /work/servers/mysql/bin/mysqlbinlog /usr/local/bin/mysqlbinlog;" +
				"ln -s /work/servers/mysql/bin/mysql /usr/local/bin/mysql"

			if err := sshDoShell(f_ip, cmd); err != nil {
				fmt.Printf("\n %c[1;40;33m%s%c[0m\n\n", 0x1B, f_ip+"'s mysql and mysqlbinlog are exist", 0x1B)
			}
			fmt.Println(f_ip + " candicate keepalived is ready")
			slave_complete <- 0
		}(ip)

		<-slave_complete
	}

	fmt.Printf("\n %c[1;40;32m%s%c[0m\n\n", 0x1B, "All candicate keepalived is ready", 0x1B)
	candicate_complete <- 0
}

func buildSlave() {
	priority := 100

	// 给每个从服务器配置
	for _, ip := range strings.Split(sip, ",") {
		priority -= 10
		cmd := "yum install -y epel-release ;" +
			"yum install -y http://120.92.156.238:8888/mha/mha4mysql-node.rpm;" +
			"ln -s /work/servers/mysql/bin/mysqlbinlog /usr/local/bin/mysqlbinlog;" +
			"ln -s /work/servers/mysql/bin/mysql /usr/local/bin/mysql"
		if err := sshDoShell(ip, cmd); err != nil {
			fmt.Printf("\n %c[1;40;33m%s%c[0m\n\n", 0x1B, ip+"'s mysql and mysqlbinlog are exist", 0x1B)
		}
	}

	fmt.Printf("\n %c[1;40;32m%s%c[0m\n\n", 0x1B, "All slave keepalived is ready", 0x1B)
	slave_complete <- 0
}

// 执行shell命令
func myCmd(bash string, shell ...string) error {
	contentArray := make([]string, 0, 5)
	cmd := exec.Command(bash, shell...)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		fmt.Println(cmd.Stderr, "error=>", err.Error())
	}

	_ = cmd.Start()

	reader := bufio.NewReader(stdout)

	contentArray = contentArray[0:0]
	var index int
	//实时循环读取输出流中的一行内容
	for {
		line, err2 := reader.ReadString('\n')
		if err2 != nil || io.EOF == err2 {
			break
		}
		fmt.Print(line)
		index++
		contentArray = append(contentArray, line)
	}
	err = cmd.Wait()

	if err != nil {
		fmt.Printf("Execute Shell %s: ", shell)
		return errors.New("failed with error:" + err.Error())
	}

	return nil
}

// 写到指定配置文件中
func myWrite(config string, word ...string) error {
	for _, i := range word {
		f, err := os.OpenFile(config, os.O_WRONLY, 0644)
		if err != nil {
			fmt.Println("cacheFileList.yml file create failed. err: " + err.Error())
			return errors.New(i)
		} else {
			// 查找文件末尾的偏移量
			n, _ := f.Seek(0, os.SEEK_END)
			// 从末尾的偏移量开始写入内容
			_, err = f.WriteAt([]byte(i+"\n"), n)
		}
		_ = f.Close()

		if err != nil {
			fmt.Println("cacheFileList.yml file writed failed. err: " + err.Error())
			return errors.New(i)
		}
	}
	return nil
}

// 执行安装mha
func buildMha() error {

	// 安装必须软件
	if err := myCmd("/usr/bin/yum", "install", "-y", "epel-release"); err != nil {
		return errors.New(err.Error() + " -- install epel error")
	}

	// 判断是否安装，未安装则安装
	if err := myCmd("/usr/bin/yum", "list", "mha4mysql-manager", "mha4mysql-node"); err != nil {
		fmt.Println("start install mha4mysql")
		if err := myCmd("/usr/bin/yum", "install", "-y", installUrl+"mha4mysql-manager.rpm",
			installUrl+"mha4mysql-node.rpm"); err != nil {
			return errors.New(err.Error() + " -- install mha error")
		}
	}

	// 初始化、下载配置文件
	if err := myCmd("/usr/bin/mkdir", "-p", mhaConfigDir); err != nil {
		return errors.New(err.Error() + " -- mkdir error")
	}

	if err := myCmd("/usr/bin/mkdir", "-p", "/work/logs/mha/"); err != nil {
		return errors.New(err.Error() + " -- mkdir error")
	}

	if err := myCmd("/usr/bin/wget", installUrl+mhaConfigFile, "-O", mhaConfigDir+mhaConfigFile); err != nil {
		return errors.New(err.Error() + " -- get config file error")
	}

	if err := myCmd("/usr/bin/wget", installUrl+"master_ip_failover", "-O", "/work/sh/master_ip_failover"); err != nil {
		return errors.New(err.Error() + " -- get shell file error")
	}

	if err := myCmd("/usr/bin/chmod", "755", "/work/sh/master_ip_failover"); err != nil {
		return errors.New(err.Error() + " -- change user for shell file error")
	}

	//创建文件
	if _, err := os.Stat(mhaConfigDir + mhaConfigFile); err != nil {
		if ! os.IsExist(err) {
			newFile, err := os.Create(mhaConfigDir + mhaConfigFile)
			if err != nil {
				log.Panic(err)
			}
			log.Println(newFile)
			_ = newFile.Close()
		}
	}
	if err := myWrite(mhaConfigDir+mhaConfigFile, "[server1]", "hostname="+mip, ""); err != nil {
		log.Panic(err)
	}

	// 写配置到mha文件中
	cnum := 0

	for num, ip := range strings.Split(cip, ",") {
		if err := myWrite(mhaConfigDir+mhaConfigFile, "[server"+strconv.Itoa(num+2)+"]", "hostname="+ip,
			"candidate_master=1", ""); err != nil {
			log.Panic(err)
		}
		cnum ++
	}

	// 如果有非待选从库，将其写配置到mha文件中
	if sip != "empty" {
		for snum, ip := range strings.Split(sip, ",") {
			if err := myWrite(mhaConfigDir+mhaConfigFile, "[server"+strconv.Itoa(snum+cnum+2)+"]",
				"hostname="+ip, "no_master=1", ""); err != nil {
				log.Panic(err)
			}
		}
	}

	fmt.Printf("\n %c[1;40;32m%s%c[0m\n\n", 0x1B, "build mha successfully , waite to check Mha", 0x1B)
	return nil
}

func startMha() error {
	// 检查ssh连通性
	if err := myCmd("/usr/bin/masterha_check_ssh", "--conf=/work/config/mha/mha.conf"); err != nil {
		return errors.New(err.Error() + " -- mha sshd test error")
	}

	// 检查集群状态
	if err := myCmd("/usr/bin/masterha_check_repl", "--conf=/work/config/mha/mha.conf"); err != nil {
		return errors.New(err.Error() + " -- mha repl test error")
	}

	return nil
}

func main() {
	// 获取外部变量
	flag.StringVar(&mip, "master", "Error", "Master IP")
	flag.StringVar(&cip, "candicate", "Error", "Candicate master IP")
	flag.StringVar(&sip, "slave", "empty", "Slaves IP")
	flag.StringVar(&vip, "vip", "Error", "VIP")
	flag.Parse()

	if mip == "Error" || cip == "Error" || vip == "Error" {
		flag.Usage()
		return
	}

	go buildMaster()
	go buildCandicate()
	go buildSlave()

	if err := buildMha(); err != nil {
		log.Panic(err)
	}

	<-master_complete
	<-candicate_complete
	<-slave_complete

	if err := startMha(); err != nil {
		log.Panic(err)
	}

	fmt.Printf("\n %c[1;40;32m%s%c[0m\n\n", 0x1B, "Server for MasterHA is Ready! you can use this to start mha", 0x1B)
	fmt.Printf("\n%c[1;40;36m%s%c[0m", 0x1B, "nohup masterha_manager --conf=/work/config/mha/mha.conf"+
		" --remove_dead_master_conf --ignore_last_failover < /dev/null > /work/logs/mha/mha.log 2>&1 &", 0x1B)
	fmt.Printf("\n%c[1;40;36m%s%c[0m\n\n", 0x1B, "sleep 5 ; masterha_check_status --conf=/work/config/mha/mha.conf", 0x1B)
}
