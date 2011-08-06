is_db_valid() {
    config="$V_USERS/$user/db.conf"
    check_db=$(grep "DB='$database'" $config)

    # Checking result
    if [ -z "$check_db" ]; then
        echo "Error: db not added"
        log_event 'debug' "$E_DB_NOTEXIST $V_EVENT"
        exit $E_DB_NOTEXIST
    fi
}

is_db_new() {
    # Parsing domain values
    check_db=$(grep -F "DB='$database'" $V_USERS/$user/db.conf)

    # Checking result
    if [ ! -z "$check_db" ]; then
        echo "Error: db exist"
        log_event 'debug' "$E_DB_EXIST $V_EVENT"
        exit $E_DB_EXIST
    fi
}

# Shell list for single database
db_shell_single_list() {

    # Reading file line by line
    line=$(grep "DB='$database'" $conf)

    # Parsing key=value
    for key in $line; do
        eval ${key%%=*}=${key#*=}
    done

    # Print result line
    for field in $fields; do 
        eval key="$field"
        echo "${field//$/}: $key "
    done
}

# Json single list
db_json_single_list() {
    i=1

    # Define words number
    last_word=$(echo "$fields" | wc -w)

    # Reading file line by line
    line=$(grep "DB='$database'" $conf)

    # Print top bracket
    echo '{'

    # Parsing key=value
    for key in $line; do
        eval ${key%%=*}=${key#*=}
    done

    # Starting output loop
    for field in $fields; do

        # Parsing key=value
        eval value=$field

        # Checking first field
        if [ "$i" -eq 1 ]; then
            echo -e "\t\"$value\": {"
        else
            if [ "$last_word" -eq "$i" ]; then
                echo -e "\t\t\"${field//$/}\": \"${value//,/, }\""
            else
                echo -e "\t\t\"${field//$/}\": \"${value//,/, }\","
            fi
        fi

        # Updating iterator
        i=$(( i + 1))
    done

    # If there was any output
    if [ -n "$value" ]; then
        echo -e "\t}"
    fi

    # Printing bottom json bracket
    echo -e "}"
}

# Shell list for single database host
dbhost_shell_single_list() {

    # Reading file line by line
    line=$(grep "HOST='$host'" $conf)

    # Parsing key=value
    for key in $line; do
        eval ${key%%=*}=${key#*=}
    done

    # Print result line
    for field in $fields; do 
        eval key="$field"
        echo "${field//$/}: $key"
    done
}

# Json list for single db host
dbhost_json_single_list() {

    # Definigng variables
    i=1                         # iterator

    # Define words number
    last_word=$(echo "$fields" | wc -w)

    # Reading file line by line
    line=$(grep "HOST='$host'" $conf)

    # Print top bracket
    echo '{'

    # Parsing key=value
    for key in $line; do
        eval ${key%%=*}=${key#*=}
    done

    # Starting output loop
    for field in $fields; do

        # Parsing key=value
        eval value=$field

        # Checking first field
        if [ "$i" -eq 1 ]; then
            echo -e "\t\"$value\": {"
        else
            if [ "$last_word" -eq "$i" ]; then
                echo -e "\t\t\"${field//$/}\": \"${value//,/, }\""
            else
                echo -e "\t\t\"${field//$/}\": \"${value//,/, }\","
            fi
        fi

        # Updating iterator
        i=$(( i + 1))
    done
    # If there was any output
    if [ -n "$value" ]; then
        echo -e "\t}"
    fi

    # Printing bottom json bracket
    echo -e "}"
}

# Checking database host existance
is_db_host_valid() {
    config="$V_DB/$type.conf"
    check_db=$(grep "HOST='$host'" $config)

    # Checking result
    if [ -z "$check_db" ]; then
        echo "Error: host not added"
        log_event 'debug' "$E_DBHOST_NOTEXIST $V_EVENT"
        exit $E_DBHOST_NOTEXIST
    fi
}

get_next_db_host() {
    # Defining vars
    config="$V_DB/$type.conf"
    host="empty"
    host_str=$(grep "ACTIVE='yes'" $config)

    # Checking rows count
    check_row=$(echo "$host_str"|wc -l)

    # Checking empty result
    if [ 0 -eq "$check_row" ]; then
        echo "$host"
        exit
    fi

    # Checking one host
    if [ 1 -eq "$check_row" ]; then
        for key in $host_str; do
            eval ${key%%=*}="${key#*=}"
        done
        users=$(echo -e "${U_SYS_USERS//,/\n}"|wc -l)
        if [ "$MAX_DB" -gt "$U_DB_BASES" ] && [ $MAX_USERS -gt "$users" ];then
            host=$HOST
        fi

        echo "$host"
        exit
    fi

    # Defining balancing function
    weight_balance() {
        ow='100'                # old_weght
        IFS=$'\n'
        for db in $host_str; do
            for key in $(echo $db|sed -e "s/' /'\n/g"); do
                eval ${key%%=*}="${key#*=}"
            done
            weight=$(echo "$U_DB_BASES * 100 / $MAX_DB"|bc)
            users=$(echo -e "${U_SYS_USERS//,/\n}"|wc -l)

            if [ "$ow" -gt "$weight" ] && [ $MAX_USERS -gt "$users" ]; then
                host="$HOST"
                ow="$weight"
            fi
        done
    }

    # Defining random balancing function
    random_balance() {
    # Parsing host pool
        HOST_LIST=''
        IFS=$'\n'
        for db in $host_str; do
            for key in $(echo $db|sed -e "s/' /'\n/g"); do
                eval ${key%%=*}="${key#*=}"
            done

            users=$(echo -e "${U_SYS_USERS//,/\n}"|wc -l)

            if [ "$MAX_DB" -gt "$U_DB_BASES" ] && [ $MAX_USERS -gt "$users" ]
            then
                HOST_LIST="$HOST_LIST$HOST "
            fi
        done

        # Checking one host
        if [ 2 -eq $(echo -e "${HOST_LIST// /\n}"|wc -l) ]; then
            host="${HOST_LIST// /\n}"# should test with disabled host
        else
            # Selecting all hosts
            HOSTS=($(echo -e "${HOST_LIST// /\n}"))
            num=${#HOSTS[*]}
            host="${HOSTS[$((RANDOM%num))]}"
        fi
    }

    # Defining first balancing function
    first_balance() {
        # Parsing host pool
        IFS=$'\n'
        for db in $host_str; do
            for key in $(echo $db|sed -e "s/' /'\n/g"); do
                eval ${key%%=*}="${key#*=}"
            done

            users=$(echo -e "${U_SYS_USERS//,/\n}"|wc -l)
            if [ "$MAX_DB" -gt "$U_DB_BASES" ] && [ $MAX_USERS -gt "$users" ]
            then
                host="$HOST"
                break
            fi
        done
    }

    # Parsing domain values
    db_balance=$(grep "DB_BALANCE='" $V_CONF/vesta.conf|cut -f 2 -d \')

    case $db_balance in 
        weight) weight_balance "$config" ;;
        random) random_balance "$config" ;;
        first) first_balance "$config" ;;
        *) random_balance "$config" ;;
    esac
    echo "$host"
}

increase_db_value() {
    # Defining vars
    conf="$V_DB/$type.conf"
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
            new_str="$new_str PORT='$PORT' MAX_USERS='$MAX_USERS'";
            new_str="$new_str MAX_DB='$MAX_DB' U_SYS_USERS='$U_SYS_USERS'";
            new_str="$new_str U_DB_BASES='$U_DB_BASES'  ACTIVE='$ACTIVE'";
            new_str="$new_str DATE='$DATE'";;
        pgsql) new_str="HOST='$HOST' USER='$USER' PASSWORD='$PASSWORD'";
            new_str="$new_str PORT='$PORT' TPL='$TPL'";
            new_str="$new_str MAX_USERS='$MAX_USERS' MAX_DB='$MAX_DB'";
            new_str="$new_str U_SYS_USERS='$U_SYS_USERS'";
            new_str="$new_str U_DB_BASES='$U_DB_BASES' ACTIVE='$ACTIVE'";
            new_str="$new_str DATE='$DATE'";;
    esac

    # Changing config
    sed -i "s/$host_str/$new_str/g" $conf
}

decrease_db_value() {
    # Defining vars
    conf="$V_DB/$type.conf"
    host_str=$(grep "HOST='$host'" $conf)

    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    # Decreasing db_bases usage value
    U_DB_BASES=$((U_DB_BASES - 1))

    # Checking user databases on that host
    udb=$(grep "TYPE='$type'" $V_USERS/$user/db.conf|grep "HOST='$host'"|wc -l)
    if [ 2 -gt "$udb" ]; then
        U_SYS_USERS=$(echo "$U_SYS_USERS" |  sed -e "s/,/\n/g" |\
            sed -e "/^$user$/d" | sed -e :a -e '$!N;s/\n/,/;ta')
    fi

    # Concatenating db string
    case $type in
        mysql) new_str="HOST='$HOST' USER='$USER' PASSWORD='$PASSWORD'";
            new_str="$new_str PORT='$PORT' MAX_USERS='$MAX_USERS'";
            new_str="$new_str MAX_DB='$MAX_DB' U_SYS_USERS='$U_SYS_USERS'";
            new_str="$new_str U_DB_BASES='$U_DB_BASES'  ACTIVE='$ACTIVE'";
            new_str="$new_str DATE='$DATE'";;
        pgsql) new_str="HOST='$HOST' USER='$USER' PASSWORD='$PASSWORD'";
            new_str="$new_str PORT='$PORT' TPL='$TPL'";
            new_str="$new_str MAX_USERS='$MAX_USERS' MAX_DB='$MAX_DB'";
            new_str="$new_str U_SYS_USERS='$U_SYS_USERS'";
            new_str="$new_str U_DB_BASES='$U_DB_BASES' ACTIVE='$ACTIVE'";
            new_str="$new_str DATE='$DATE'";;
    esac

    # Changing config
    sed -i "s/$host_str/$new_str/g" $conf
}

create_db_mysql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $V_DB/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    # Adding database & checking result
    $sql "CREATE DATABASE $database" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
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
    host_str=$(grep "HOST='$host'" $V_DB/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -d $TPL -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    # Adding database & checking result
    $sql "CREATE DATABASE $database" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    $sql "CREATE ROLE $db_user WITH LOGIN PASSWORD '$db_password'"
    $sql "GRANT ALL PRIVILEGES ON DATABASE $database TO $db_user"
    export PGPASSWORD='pgsqk'
}

is_db_host_new() {
    if [ -e "$V_DB/$type.conf" ]; then
        check_host=$(grep "HOST='$host'" $V_DB/$type.conf)
        if [ ! -z "$check_host" ]; then
            echo "Error: db host exist"
            log_event 'debug' "$E_DBHOST_EXIST $V_EVENT"
            exit $E_DBHOST_EXIST
        fi
    fi
}

is_mysql_host_alive() {
    # Checking connection
    sql="mysql -h $host -u $db_user -p$db_password -P$port -e"
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi
}

is_pgsql_host_alive() {
    # Checking connection
    export PGPASSWORD="$db_password"
    sql="psql -h $host -U $db_user -d $template -p $port -c"
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi
}

is_db_suspended() {
    config="$V_USERS/$user/db.conf"
    check_db=$(grep "DB='$database'" $config|grep "SUSPEND='yes'")

    # Checking result
    if [ ! -z "$check_db" ]; then
        echo "Error: db suspended"
        log_event 'debug' "$E_DB_SUSPENDED $V_EVENT"
        exit $E_DB_SUSPENDED
    fi
}

is_db_unsuspended() {
    config="$V_USERS/$user/db.conf"
    check_db=$(grep "DB='$database'" $config|grep "SUSPEND='yes'")

    # Checking result
    if [ -z "$check_db" ]; then
        echo "Error: db unsuspended"
        log_event 'debug' "$E_DB_UNSUSPENDED $V_EVENT"
        exit $E_DB_UNSUSPENDED
    fi
}

is_db_user_valid() {
    config="$V_USERS/$user/db.conf"
    check_db=$(grep "DB='$database'" $config|grep "USER='$db_user'")

    # Checking result
    if [ -z "$check_db" ]; then
        echo "Error: dbuser not exist"
        log_event 'debug' "$E_DBUSER_NOTEXIST $V_EVENT"
        exit $E_DBUSER_NOTEXIST
    fi
}

change_db_mysql_password() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $V_DB/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
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
    host_str=$(grep "HOST='$host'" $V_DB/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -d $TPL -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    $sql "ALTER ROLE $db_user WITH LOGIN PASSWORD '$db_password'" >/dev/null
    export PGPASSWORD='pgsqk'
}

get_db_value() {
    # Defining vars
    key="$1"
    db_str=$(grep "DB='$database'" $V_USERS/$user/db.conf)

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
    host_str=$(grep "HOST='$host'" $V_DB/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    # Deleting database & checking result
    $sql "DROP DATABASE $database" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    # Deleting user
    check_users=$(grep "USER='$db_user'" $V_USERS/$user/db.conf |wc -l)
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
    host_str=$(grep "HOST='$host'" $V_DB/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -d $TPL -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    # Deleting database & checking result
    $sql "DROP DATABASE $database" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    # Deleting user
    check_users=$(grep "USER='$db_user'" $V_USERS/$user/db.conf |wc -l)
    if [ 1 -ge "$check_users" ]; then
        $sql "DROP ROLE $db_user" >/dev/null 2>&1
    else
        $sql "REVOKE ALL PRIVILEGES ON $database FROM $db_user">/dev/null
    fi
    export PGPASSWORD='pgsqk'
}


del_db_vesta() {
    conf="$V_USERS/$user/db.conf"

    # Parsing domains
    string=$( grep -n "DB='$database'" $conf | cut -f 1 -d : )
    if [ -z "$string" ]; then
        echo "Error: parse error"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi
    sed -i "$string d" $conf
}

is_db_host_free() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $V_DB/$type.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    # Checking U_DB_BASES
    if [ 0 -ne "$U_DB_BASES" ]; then
        echo "Error: host is used"
        log_event 'debug' "$E_DBHOST_BUSY $V_EVENT"
        exit $E_DBHOST_BUSY
    fi
}

del_dbhost_vesta() {
    conf="$V_DB/$type.conf"

    # Parsing domains
    string=$( grep -n "HOST='$host'" $conf | cut -f 1 -d : )
    if [ -z "$string" ]; then
        echo "Error: parse error"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi
    sed -i "$string d" $conf
}

update_db_base_value() {
    key="$1"
    value="$2"

    # Defining conf
    conf="$V_USERS/$user/db.conf"

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
    host_str=$(grep "HOST='$host'" $V_DB/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    # Suspending user
    $sql "REVOKE ALL ON $database.* FROM '$db_user'@'%'"
    $sql "FLUSH PRIVILEGES"
}

suspend_db_pgsql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $V_DB/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -d $TPL -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    # Suspending user
    $sql "REVOKE ALL PRIVILEGES ON $database FROM $db_user">/dev/null
    export PGPASSWORD='pgsqk'
}

unsuspend_db_mysql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $V_DB/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    # Unsuspending user
    $sql "GRANT ALL ON $database.* to '$db_user'@'%'"
    $sql "FLUSH PRIVILEGES"
}

unsuspend_db_pgsql() {
    # Defining vars
    host_str=$(grep "HOST='$host'" $V_DB/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -d $TPL -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    # Unsuspending user
    $sql "GRANT ALL PRIVILEGES ON DATABASE $database TO $db_user" >/dev/null
    export PGPASSWORD='pgsqk'
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
    host_str=$(grep "HOST='$host'" $V_DB/mysql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done
    sql="mysql -h $HOST -u $USER -p$PASSWORD -P$PORT -e"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $PORT ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1; code="$?"
    if [ '0' -ne "$code" ]; then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
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
    host_str=$(grep "HOST='$host'" $V_DB/pgsql.conf)
    for key in $host_str; do
        eval ${key%%=*}=${key#*=}
    done

    export PGPASSWORD="$PASSWORD"
    sql="psql -h $HOST -U $USER -d $TPL -p $PORT -c"

    # Checking empty vars
    if [ -z $HOST ] || [ -z $USER ] || [ -z $PASSWORD ] || [ -z $TPL ]; then
        echo "Error: config is broken"
        log_event 'debug' "$E_PARSE_ERROR $V_EVENT"
        exit $E_PARSE_ERROR
    fi

    # Checking connection
    $sql "SELECT VERSION()" >/dev/null 2>&1;code="$?"
    if [ '0' -ne "$code" ];  then
        echo "Error: Connect failed"
        log_event 'debug' "$E_DBHOST_UNAVAILABLE $V_EVENT"
        exit $E_DBHOST_UNAVAILABLE
    fi

    # Raw query
    raq_query=$($sql "SELECT pg_database_size('$database');")
    raw_size=$(echo raq_query | grep -v "-" | grep -v 'row' | sed -e "/^$/d"|\
        awk '{print $1}')

    # Checking null output (this means error btw)
    if [ -z "$raw_size" ]; then
        raw_size='0'
    fi

    # Converting to MB
    size=$(expr $raw_size \ 1048576)

    # Rounding zero size
    if [ "$size" -eq '0' ]; then
        echo '1'
    else
        echo "$size"
    fi
}
