#Pre-installation mysql or mariadb
mysql_preinstall_settings(){

    display_menu mysql 6

    if [ "$mysql" != "do_not_install" ];then
        if [ "$mysql" == "${mysql5_5_filename}" ] || [ "$mysql" == "${mysql5_6_filename}" ] || [ "$mysql" == "${mysql5_7_filename}" ];then
            #mysql data
            read -p "mysql data location(default:${mysql_location}/data,leave blank for default): " mysql_data_location
            mysql_data_location=${mysql_data_location:=$mysql_location/data}
            mysql_data_location=`filter_location "$mysql_data_location"`
            echo "$mysql data location: $mysql_data_location"

            #set mysql root password
            read -p "mysql server root password (default:root,leave blank for default): " mysql_root_pass
            mysql_root_pass=${mysql_root_pass:=root}
            echo "$mysql root password: $mysql_root_pass"

            if [ "$mysql" == "${mysql5_5_filename}" ];then
                mysql_configure_args="-DCMAKE_INSTALL_PREFIX=${mysql_location} \
                -DMYSQL_DATADIR=${mysql_data_location} \
                -DSYSCONFDIR=/etc \
                -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
                -DDEFAULT_CHARSET=utf8mb4 \
                -DDEFAULT_COLLATION=utf8mb4_general_ci \
                -DWITH_EXTRA_CHARSETS=complex \
                -DWITH_READLINE=1 \
                -DENABLED_LOCAL_INFILE=1"
            elif [ "$mysql" == "${mysql5_6_filename}" ];then
                mysql_configure_args="-DCMAKE_INSTALL_PREFIX=${mysql_location} \
                -DMYSQL_DATADIR=${mysql_data_location} \
                -DSYSCONFDIR=/etc \
                -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
                -DDEFAULT_CHARSET=utf8mb4 \
                -DDEFAULT_COLLATION=utf8mb4_general_ci \
                -DWITH_EXTRA_CHARSETS=complex \
                -DENABLED_LOCAL_INFILE=1"
            elif [ "$mysql" == "${mysql5_7_filename}" ];then
                mysql_configure_args="-DCMAKE_INSTALL_PREFIX=${mysql_location} \
                -DWITH_BOOST=${cur_dir}/software/${boost_filename}  \
                -DMYSQL_DATADIR=${mysql_data_location} \
                -DSYSCONFDIR=/etc \
                -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
                -DDEFAULT_CHARSET=utf8mb4 \
                -DDEFAULT_COLLATION=utf8mb4_general_ci \
                -DWITH_EXTRA_CHARSETS=complex \
                -DWITH_EMBEDDED_SERVER=1 \
                -DENABLED_LOCAL_INFILE=1"
            fi
        elif [ "$mysql" == "${mariadb5_5_filename}" ] || [ "$mysql" == "${mariadb10_0_filename}" ] || [ "$mysql" == "${mariadb10_1_filename}" ];then
            #mariadb data
            read -p "mariadb data location(default:${mariadb_location}/data,leave blank for default): " mariadb_data_location
            mariadb_data_location=${mariadb_data_location:=$mariadb_location/data}
            mariadb_data_location=`filter_location "$mariadb_data_location"`
            echo "mariadb data location: $mariadb_data_location"

            #set mariadb root password
            read -p "mariadb server root password (default:root,leave blank for default): " mariadb_root_pass
            mariadb_root_pass=${mariadb_root_pass:=root}
            echo "$mysql root password: $mariadb_root_pass"
        fi
    fi
}

#Install mysql server
install_mysqld(){

    id -u mysql >/dev/null 2>&1
    [ $? -ne 0 ] && useradd -M -s /sbin/nologin mysql
    mkdir -p ${mysql_data_location}
    chown -R mysql:mysql ${mysql_location} ${mysql_data_location}

    if check_sys packageManager apt;then
        apt-get -y install libncurses5-dev cmake m4 bison libaio1 libaio-dev
    elif check_sys packageManager yum;then
        yum -y install ncurses-devel cmake m4 bison libaio perl-Data-Dumper
    fi

    cd ${cur_dir}/software/

    if [ "$mysql" == "${mysql5_5_filename}" ];then

        download_file  "${mysql5_5_filename}.tar.gz"
        tar zxf ${mysql5_5_filename}.tar.gz
        cd ${mysql5_5_filename}
        error_detect "cmake ${mysql_configure_args}"

        error_detect "parallel_make"
        error_detect "make install"
        config_mysql 5.5
        
    elif [ "$mysql" == "${mysql5_6_filename}" ];then

        download_file "${mysql5_6_filename}.tar.gz"
        tar zxf ${mysql5_6_filename}.tar.gz
        cd ${mysql5_6_filename}
        error_detect "cmake ${mysql_configure_args}"
        error_detect "parallel_make"
        error_detect "make install"
        config_mysql 5.6

    elif [ "$mysql" == "${mysql5_7_filename}" ];then

        download_file "${boost_filename}.tar.gz"
        tar zxf ${boost_filename}.tar.gz

        download_file "${mysql5_7_filename}.tar.gz"
        tar zxf ${mysql5_7_filename}.tar.gz
        cd ${mysql5_7_filename}
        error_detect "cmake ${mysql_configure_args}"
        error_detect "parallel_make"
        error_detect "make install"
        config_mysql 5.7
    fi

    add_to_env "${mysql_location}"
    if [ -d "${mysql_location}/lib" ] && [ ! -d "${mysql_location}/lib64" ];then
        cd ${mysql_location}
        ln -s lib lib64
    fi
}

#Configuration mysql
config_mysql(){
    local version=$1

    if [ -f /etc/my.cnf ];then
        mv /etc/my.cnf /etc/my.cnf.bak
    fi
    [ -d '/etc/mysql' ] && mv /etc/mysql{,_bk}

    #create my.cnf
    create_mysql_my_cnf "${mysql_data_location}" "false" "false" "/etc/my.cnf"

    cp -f ${mysql_location}/support-files/mysql.server /etc/init.d/mysqld
    sed -i "s:^basedir=.*:basedir=${mysql_location}:g" /etc/init.d/mysqld
    sed -i "s:^datadir=.*:datadir=${mysql_data_location}:g" /etc/init.d/mysqld
    chmod +x /etc/init.d/mysqld

    if [ ${version} == "5.5" ] || [ ${version} == "5.6" ];then
        ${mysql_location}/scripts/mysql_install_db --basedir=${mysql_location} --datadir=${mysql_data_location} --user=mysql
    elif [ ${version} == "5.7" ];then
        ${mysql_location}/bin/mysqld --initialize-insecure --basedir=${mysql_location} --datadir=${mysql_data_location} --user=mysql
    fi

    rm -f /usr/bin/mysql /usr/bin/mysqldump
    ln -s ${mysql_location}/bin/mysql /usr/bin/mysql
    ln -s ${mysql_location}/bin/mysqldump /usr/bin/mysqldump
    boot_start mysqld

    /etc/init.d/mysqld start
    ${mysql_location}/bin/mysql -e "grant all privileges on *.* to root@'127.0.0.1' identified by \"${mysql_root_pass}\" with grant option;"
    ${mysql_location}/bin/mysql -e "grant all privileges on *.* to root@'localhost' identified by \"${mysql_root_pass}\" with grant option;"
    ${mysql_location}/bin/mysql -uroot -p${mysql_root_pass} <<EOF
drop database if exists test;
delete from mysql.user where not (user='root');
delete from mysql.user where password='';
delete from mysql.db where user='';
flush privileges;
exit
EOF
    /etc/init.d/mysqld stop

    rm -f /etc/ld.so.conf.d/mysql.conf
    touch /etc/ld.so.conf.d/mysql.conf
    echo "${mysql_location}/lib" >> /etc/ld.so.conf.d/mysql.conf
    echo "${mysql_location}/lib64" >> /etc/ld.so.conf.d/mysql.conf
    ldconfig
}

#Install mariadb server
install_mariadb(){

    id -u mysql >/dev/null 2>&1
    [ $? -ne 0 ] && useradd -M -s /sbin/nologin mysql
    mkdir -p ${mariadb_data_location}
    chown -R mysql:mysql ${mariadb_location} ${mariadb_data_location}

    if check_sys packageManager apt;then
        apt-get -y install libncurses5-dev cmake m4 bison libaio1 libaio-dev
    elif check_sys packageManager yum;then
        yum -y install ncurses-devel cmake m4 bison libaio perl-Data-Dumper
    fi

    local down_addr=https://downloads.mariadb.org/f
    local libc_version=`getconf -a | grep GNU_LIBC_VERSION | awk '{print $NF}'`

    if version_lt ${libc_version} 2.14; then
        glibc_flag=linux
    else
        glibc_flag=linux-glibc_214
    fi

    is_64bit && sys_bit_a=x86_64 || sys_bit_a=x86
    is_64bit && sys_bit_b=x86_64 || sys_bit_b=i686

    cd ${cur_dir}/software/

    if [ "$mysql" == "${mariadb5_5_filename}" ] || [ "$mysql" == "${mariadb10_0_filename}" ] || [ "$mysql" == "${mariadb10_1_filename}" ];then
        download_from_url "${mysql}-${glibc_flag}-${sys_bit_b}.tar.gz" "${down_addr}/${mysql}/bintar-${glibc_flag}-${sys_bit_a}/${mysql}-${glibc_flag}-${sys_bit_b}.tar.gz"
        echo "Extracting MariaDB files..."
        tar zxf ${mysql}-${glibc_flag}-${sys_bit_b}.tar.gz
        echo "Moving MariaDB files..."
        mv ${mysql}-*-${sys_bit_b}/* ${mariadb_location}
    fi

    add_to_env "${mariadb_location}"

    if [ -d "${mariadb_location}/lib" ] && [ ! -d "${mariadb_location}/lib64" ];then
        cd ${mariadb_location}
        ln -s lib lib64
    fi

    config_mariadb
}

#Configuration mariadb
config_mariadb(){

    if [ -f /etc/my.cnf ];then
        mv /etc/my.cnf /etc/my.cnf.bak
    fi
    [ -d '/etc/mysql' ] && mv /etc/mysql{,_bk}

    #create my.cnf
    create_mysql_my_cnf "${mariadb_data_location}" "false" "false" "/etc/my.cnf"

    cp -f ${mariadb_location}/support-files/mysql.server /etc/init.d/mysqld
    sed -i "s@^basedir=.*@basedir=${mariadb_location}@" /etc/init.d/mysqld
    sed -i "s@^datadir=.*@datadir=${mariadb_data_location}@" /etc/init.d/mysqld
    chmod +x /etc/init.d/mysqld

    ${mariadb_location}/scripts/mysql_install_db --basedir=${mariadb_location} --datadir=${mariadb_data_location} --user=mysql

    rm -f /usr/bin/mysql /usr/bin/mysqldump
    ln -s ${mariadb_location}/bin/mysql /usr/bin/mysql
    ln -s ${mariadb_location}/bin/mysqldump /usr/bin/mysqldump
    boot_start mysqld

    /etc/init.d/mysqld start
    ${mariadb_location}/bin/mysql -e "grant all privileges on *.* to root@'127.0.0.1' identified by \"${mariadb_root_pass}\" with grant option;"
    ${mariadb_location}/bin/mysql -e "grant all privileges on *.* to root@'localhost' identified by \"${mariadb_root_pass}\" with grant option;"
    ${mariadb_location}/bin/mysql -uroot -p${mariadb_root_pass} <<EOF
drop database if exists test;
delete from mysql.user where not (user='root');
delete from mysql.user where password='';
delete from mysql.db where user='';
flush privileges;
exit
EOF
    /etc/init.d/mysqld stop

    rm -f /etc/ld.so.conf.d/mysql.conf
    touch /etc/ld.so.conf.d/mysql.conf
    echo "${mariadb_location}/lib" >> /etc/ld.so.conf.d/mysql.conf
    echo "${mariadb_location}/lib64" >> /etc/ld.so.conf.d/mysql.conf
    ldconfig
}
