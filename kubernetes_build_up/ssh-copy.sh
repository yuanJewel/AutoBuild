Password='M#v861zxa_PO'
yum install -y expect
expect <<EOF
spawn ssh-keygen
expect /.ssh/id_rsa {send \n}
expect Overwrite {send n\n}
expect passphrase {send \n}
expect again {send \n}
expect again {send \n}
EOF
for i in 172.16.0.216 172.16.0.217
do
expect <<EOF
spawn ssh-copy-id $i
expect connecting {send yes\n}
expect password {send $Password\n}
expect password {send $Password\n}
EOF
done
