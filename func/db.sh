is_db_valid() {
    config="$USER_DATA/db.conf"
    check_db=$(grep "DB='$database'" $config)

    # Checking result
    if [ -z "$check_db" ]; then
        echo "Error: db not added"
        log_event 'debug' "$E_NOTEXIST $EVENT"
        exit $E_NOTEXIST
    fi
}

is_db_new() {
    check_db=$(grep "DB='$database'" $USER_DATA/db.conf)
    if [ ! -z "$check_db" ]; then
        echo "Error: db exist"
        log_event 'debug' "$E_EXISTS $EVENT"
        exit $E_EXISTS
    fi
}


# Checking database host existance
is_db_host_valid() {
    config="$VESTA/conf/$type.conf"
    check_db=$(grep "HOST='$host'" $config)

    # Checking result
    if [ -z "$check_db" ]; then
        echo "Error: host not added"
        log_event 'debug' "$E_NOTEXIST $EVENT"
        exit $E_NOTEXIST
    fi
}

get_next_dbhost() {
    if [ -z "$host" ]; then
        IFS=$'\n'
        host='NULL_DB_HOST'
        config="$VESTA/conf/$type.conf"
        host_str=$(grep "SUSPENDED='no'" $config)
        check_row=$(echo "$host_str"|wc -l)

        if [ 0 -lt "$check_row" ]; then
            if [ 1 -eq "$check_row" ]; then
                for db in $host_str; do
                    eval $db
                    if [ "$MAX_DB" -gt "$U_DB_BASES" ]; then
                        host=$HOST
                    fi
                done
            else
                old_weight='100'
                for db in $host_str; do
                    eval $db
                    let weight="$U_DB_BASES * 100 / $MAX_DB" &>/dev/null
                    if [ "$old_weight" -gt "$weight" ]; then
                        host="$HOST"
                        old_weight="$weight"
                    fi
                done
            fi
        fi
    fi
}

increase_db_value() {
    # Defining vars
    conf="$VESTA/conf/$type.conf"
    host_str=$(grep "HOST='$host'" $conf)

    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    # Increasing db_bases usage value
    U_DB_BASES=$((U_DB_BASES + 1))
    # Adding user to SYS_USERS pool
    if [ -z "$U_SYS_USERS" ]; then
        U_SYS_USERS="$user"
    else
        check_users=$(echo $U_SYS_USERS|sed -e "s/,/\n/g"|grep -w "$user")
        if [ -z "$check_users" ]; then
            U_SYS_USERS="$U_SYS_USERS,$user"
        fi
    fi

    # Concatenating db string
    case $type in
        mysql) new_str="HOST='$HOST' USER='$USER' PASSWORD='$PASSWORD'";
            new_str="$new_str PORT='$PORT' MAX_DB='$MAX_DB'";
            new_str="$new_str U_SYS_USERS='$U_SYS_USERS'";
            new_str="$new_str U_DB_BASES='$U_DB_BASES' ACTIVE='$ACTIVE'";
            new_str="$new_str DATE='$DATE'";;
        pgsql) new_str="HOST='$HOST' USER='$USER' PASSWORD='$PASSWORD'";
            new_str="$new_str PORT='$PORT' TPL='$TPL' MAX_DB='$MAX_DB'";
            new_str="$new_str U_SYS_USERS='$U_SYS_USERS'";
            new_str="$new_str U_DB_BASES='$U_DB_BASES' ACTIVE='$ACTIVE'";
            new_str="$new_str DATE='$DATE'";;
    esac

    # Changing config
    sed -i "s/$host_str/$new_str/g" $conf
}

decrease_db_value() {
    # Defining vars
    conf="$VESTA/conf/$type.conf"
    host_str=$(grep "HOST='$host'" $conf)

    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    # Decreasing db_bases usage value
    U_DB_BASES=$((U_DB_BASES - 1))

    # Checking user databases on that host
    udb=$(grep "TYPE='$type'" $USER_DATA/db.conf|grep "HOST='$host'"|wc -l)
    if [ 2 -gt "$udb" ]; then
        U_SYS_USERS=$(echo "$U_SYS_USERS" |  sed -e "s/,/\n/g" |\
            sed -e "/^$user$/d" | sed -e :a -e '$!N;s/\n/,/;ta')
    fi

    # Concatenating db string
    case $type in
        mysql) new_str="HOST='$HOST' USER='$USER' PASSWORD='$PASSWORD'";
            new_str="$new_str PORT='$PORT'";
            new_str="$new_str MAX_DB='$MAX_DB' U_SYS_USERS='$U_SYS_USERS'";
            new_str="$new_str U_DB_BASES='$U_DB_BASES'  ACTIVE='$ACTIVE'";
            new_str="$new_str DATE='$DATE'";;
        pgsql) new_str="HOST='$HOST' USER='$USER' PASSWORD='$PASSWORD'";
            new_str="$new_str PORT='$PORT' TPL='$TPL'";
            new_str="$new_str MAX_DB='$MAX_DB'";
            new_str="$new_str U_SYS_USERS='$U_SYS_USERS'";
            new_str="$new_str U_DB_BASES='$U_DB_BASES' ACTIVE='$ACTIVE'";
            new_str="$new_str DATE='$DATE'";;
    esac

    # Changing config
    sed -i "s/$host_str/$new_str/g" $conf
}

create_db_mysql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Adding database & checking result
    $sql "CREATE DATABASE $database CHARACTER SET $encoding" > /dev/null 2>&1
    code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Adding user with password (% will give access to db from any ip)
    $sql "GRANT ALL ON $database.* TO '$db_user'@'%' \
             IDENTIFIED BY '$db_password'"

    # Adding grant for localhost (% doesn't do that )
    if [ "$host" = 'localhost' ]; then
        $sql "GRANT ALL ON $database.* TO '$db_user'@'localhost' \
            IDENTIFIED BY '$db_password'"
    fi

    # Flushing priveleges
    $sql "FLUSH PRIVILEGES"
}

create_db_pgsql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Adding new role
    $sql "CREATE ROLE $db_user WITH LOGIN PASSWORD '$db_password'" >/dev/null
    code=$?
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Adding database & checking result
    sql_q="CREATE DATABASE $database  OWNER $db_user" > /dev/null
    if [ "$TPL" = 'template0' ]; then
        sql_q="$sql_q ENCODING '$encoding' TEMPLATE $TPL" > /dev/null
    else
        sql_q="$sql_q TEMPLATE $TPL" > /dev/null
    fi
    $sql "$sql_q" >/dev/null


    $sql "GRANT ALL PRIVILEGES ON DATABASE $database TO $db_user" > /dev/null
    $sql "GRANT CONNECT ON DATABASE template1 to $db_user" > /dev/null
    export PGPASSWORD='pgsql'
}

is_db_host_new() {
    if [ -e "$VESTA/conf/$type.conf" ]; then
        check_host=$(grep "HOST='$host'" $VESTA/conf/$type.conf)
        if [ ! -z "$check_host" ]; then
            echo "Error: db host exist"
            log_event 'debug' "$E_EXISTS $EVENT"
            exit $E_EXISTS
        fi
    fi
}

is_mysql_host_alive() {
    # Checking connection
    sql="mysql -h $host -u $db_user -p$db_password -P$port -e"
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi
}

is_pgsql_host_alive() {
    # Checking connection
    export PGPASSWORD="$db_password"
    sql="psql -h $host -U $db_user -p $port -c "
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi
}

is_db_suspended() {
    config="$USER_DATA/db.conf"
    check_db=$(grep "DB='$database'" $config|grep "SUSPENDED='yes'")

    # Checking result
    if [ ! -z "$check_db" ]; then
        echo "Error: db suspended"
        log_event 'debug' "$E_SUSPENDED $EVENT"
        exit $E_SUSPENDED
    fi
}

is_db_unsuspended() {
    config="$USER_DATA/db.conf"
    check_db=$(grep "DB='$database'" $config|grep "SUSPENDED='yes'")

    # Checking result
    if [ -z "$check_db" ]; then
        echo "Error: db unsuspended"
        log_event 'debug' "$E_UNSUSPENDED $EVENT"
        exit $E_UNSUSPENDED
    fi
}

is_db_user_valid() {
    config="$USER_DATA/db.conf"
    check_db=$(grep "DB='$database'" $config|grep "USER='$db_user'")

    # Checking result
    if [ -z "$check_db" ]; then
        echo "Error: dbuser not exist"
        log_event 'debug' "$E_NOTEXIST $EVENT"
        exit $E_NOTEXIST
    fi
}

change_db_mysql_password() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Changing user password
    $sql "GRANT ALL ON $database.* TO '$db_user'@'%' \
             IDENTIFIED BY '$db_password'"
    $sql "GRANT ALL ON $database.* TO '$db_user'@'localhost' \
             IDENTIFIED BY '$db_password'"
    #$sql "SET PASSWORD FOR '$db_user'@'%' = PASSWORD('$db_password');"
    $sql "FLUSH PRIVILEGES"
}

change_db_pgsql_password() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    $sql "ALTER ROLE $db_user WITH LOGIN PASSWORD '$db_password'" >/dev/null
    export PGPASSWORD='pgsql'
}

get_db_value() {
    # Defining vars
    key="$1"
    db_str=$(grep "DB='$database'" $USER_DATA/db.conf)

    # Parsing key=value
    for keys in $db_str; do
        eval ${keys%%=*}=${keys#*=}
    done

    # Self reference
    eval value="$key"

    # Print value
    echo "$value"
}

del_db_mysql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Deleting database & checking result
    $sql "DROP DATABASE $database" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Deleting user
    check_users=$(grep "USER='$db_user'" $USER_DATA/db.conf |wc -l)
    if [ 1 -ge "$check_users" ]; then
        $sql "DROP USER '$db_user'@'%'"
        if [ "$host" = 'localhost' ]; then
            $sql "DROP USER '$db_user'@'localhost'"
        fi
    else
        $sql "REVOKE ALL ON $database.* from '$db_user'@'%'"
        if [ "$host" = 'localhost' ]; then
            $sql "REVOKE ALL ON $database.* from '$db_user'@'localhost'"
        fi
    fi
    $sql "FLUSH PRIVILEGES"
}

del_db_pgsql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Deleting database & checking result
    $sql "REVOKE ALL PRIVILEGES ON DATABASE $database FROM $db_user">/dev/null
    $sql "DROP DATABASE $database" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Deleting user
    check_users=$(grep "USER='$db_user'" $USER_DATA/db.conf |wc -l)
    if [ 1 -ge "$check_users" ]; then
        $sql "REVOKE CONNECT ON DATABASE template1 FROM $db_user" >/dev/null
        $sql "DROP ROLE $db_user" >/dev/null
    fi

    export PGPASSWORD='pgsql'
}


del_db_vesta() {
    conf="$USER_DATA/db.conf"

    # Parsing domains
    string=$( grep -n "DB='$database'" $conf | cut -f 1 -d : )
    if [ -z "$string" ]; then
        echo "Error: parse error"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi
    sed -i "$string d" $conf
}

dump_db_mysql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"
    dumper="mysqldump -h $HOST -u $USER -p$PASSWORD -P$PORT -r"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Dumping database
    $dumper $dump $database

    # Dumping user grants
    $sql "SHOW GRANTS FOR $db_user@localhost" | grep -v "Grants for" > $grants
    $sql "SHOW GRANTS FOR $db_user@'%'" | grep -v "Grants for" >> $grants
}

dump_db_pgsql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -p $PORT -c"
    dumper="pg_dump -h $HOST -U $USER -p $PORT -c -d -O -x -i -f"
    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Dumping database
    $dumper $dump $database

    # Dumping user grants
    md5=$($sql "SELECT rolpassword FROM pg_authid WHERE rolname='$db_user';")
    md5=$(echo "$md5" | head -n 1 | cut -f 2 -d ' ')
    pw_str="UPDATE pg_authid SET rolpassword='$md5' WHERE rolname='$db_user';"
    gr_str="GRANT ALL PRIVILEGES ON DATABASE $database to '$db_user'"
    echo -e "$pw_str\n$gr_str" >> $grants
    export PGPASSWORD='pgsql'
}



is_db_host_free() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/$type.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    # Checking U_DB_BASES
    if [ 0 -ne "$U_DB_BASES" ]; then
        echo "Error: host is used"
        log_event 'debug' "$E_INUSE $EVENT"
        exit $E_INUSE
    fi
}

del_dbhost_vesta() {
    conf="$VESTA/conf/$type.conf"

    # Parsing domains
    string=$( grep -n "HOST='$host'" $conf | cut -f 1 -d : )
    if [ -z "$string" ]; then
        echo "Error: parse error"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi
    sed -i "$string d" $conf
}

update_db_base_value() {
    key="$1"
    value="$2"

    # Defining conf
    conf="$USER_DATA/db.conf"

    # Parsing conf
    db_str=$(grep -n "DB='$database'" $conf)
    str_number=$(echo $db_str | cut -f 1 -d ':')
    str=$(echo $db_str | cut -f 2 -d ':')

    # Reading key=values
    for keys in $str; do
        eval ${keys%%=*}=${keys#*=}
    done

    # Defining clean key
    c_key=$(echo "${key//$/}")

    eval old="${key}"

    # Escaping slashes
    old=$(echo "$old" | sed -e 's/\\/\\\\/g' -e 's/&/\\&/g' -e 's/\//\\\//g')
    new=$(echo "$value" | sed -e 's/\\/\\\\/g' -e 's/&/\\&/g' -e 's/\//\\\//g')

    # Updating conf
    sed -i "$str_number s/$c_key='${old//\*/\\*}'/$c_key='${new//\*/\\*}'/g"\
     $conf
}

suspend_db_mysql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Suspending user
    $sql "REVOKE ALL ON $database.* FROM '$db_user'@'%'"
    $sql "FLUSH PRIVILEGES"
}

suspend_db_pgsql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Suspending user
    $sql "REVOKE ALL PRIVILEGES ON $database FROM $db_user">/dev/null
    export PGPASSWORD='pgsql'
}

unsuspend_db_mysql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Unsuspending user
    $sql "GRANT ALL ON $database.* to '$db_user'@'%'"
    $sql "FLUSH PRIVILEGES"
}

unsuspend_db_pgsql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Unsuspending user
    $sql "GRANT ALL PRIVILEGES ON DATABASE $database TO $db_user" >/dev/null
    export PGPASSWORD='pgsql'
}

db_clear_search() {
    # Defining delimeter
    IFS=$'\n'

    # Reading file line by line
    for line in $(grep $search_string $conf); do
        # Parsing key=val
        for key in $line; do
            eval ${key%%=*}=${key#*=}
        done
        # Print result line
        eval echo "$field"
    done
}

get_disk_db_mysql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Deleting database & checking result
    query="SELECT sum( data_length + index_length ) / 1024 / 1024 \"Size\"
            FROM information_schema.TABLES WHERE table_schema='$database'"
    raw_size=$($sql "$query" |tail -n 1)

    # Checking null output (this means error btw)
    if [ "$raw_size" == 'NULL' ]; then
        raw_size='0'
    fi

    # Rounding zero size
    if [ "${raw_size:0:1}" -eq '0' ]; then
        raw_size='1'
    fi

    # Printing round size in mb
    printf "%0.f\n" $raw_size

}

get_disk_db_pgsql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $VESTA/conf/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSING $EVENT"
        exit $E_PARSING
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DB $EVENT"
        exit $E_DB
    fi

    # Raw query

    raq_query=$($sql "SELECT pg_database_size('$database');")
    raw_size=$(echo "$raq_query" | grep -v "-" | grep -v 'row' |\
        sed -e "/^$/d" |grep -v "pg_database_size" | awk '{print $1}')

    # Checking null output (this means error btw)
    if [ -z "$raw_size" ]; then
        raw_size='0'
    fi

    # Converting to MB
    size=$(expr $raw_size / 1048576)

    # Rounding zero size
    if [ "$size" -eq '0' ]; then
        echo '1'
    else
        echo "$size"
    fi
}


increase_dbhost_values() {
    conf="$VESTA/conf/$type.conf"

    # Parsing conf
    dbhost_str=$(grep -n "HOST='$host'" $conf)
    str_number=$(echo $dbhost_str | cut -f 1 -d ':')
    str=$(echo $dbhost_str | cut -f 2 -d ':')

    # Reading key=values
    eval $str

    # Defining clean key
    c_key=$(echo "${key//$/}")

    eval old="${key}"

    # Escaping slashes
    old=$(echo "$old" | sed -e 's/\\/\\\\/g' -e 's/&/\\&/g' -e 's/\//\\\//g')
    new=$(echo "$value" | sed -e 's/\\/\\\\/g' -e 's/&/\\&/g' -e 's/\//\\\//g')

    # Updating conf
    sed -i "$str_number s/$c_key='${old//\*/\\*}'/$c_key='${new//\*/\\*}'/g"\
        $conf
}
