#!/usr/bin/env bash
[[ ! ${WARDEN_DIR} ]] && >&2 echo -e "\033[31mThis script is not intended to be run directly!\033[0m" && exit 1

WARDEN_ENV_PATH="$(locateEnvPath)" || exit $?
loadEnvConfig "${WARDEN_ENV_PATH}" || exit $?
assertDockerRunning

if [[ ${WARDEN_DB:-1} -eq 0 ]]; then
  fatal "Database environment is not used (WARDEN_DB=0)."
fi

if (( ${#WARDEN_PARAMS[@]} == 0 )) || [[ "${WARDEN_PARAMS[0]}" == "help" ]]; then
  warden db --help || exit $? && exit $?
fi

## load connection information for the mysql service
DB_CONTAINER=$(warden env ps -q db)
if [[ ! ${DB_CONTAINER} ]]; then
    fatal "No container found for db service."
fi

eval "$(
    docker container inspect ${DB_CONTAINER} --format '
        {{- range .Config.Env }}{{with split . "=" -}}
            {{- index . 0 }}='\''{{ range $i, $v := . }}{{ if $i }}{{ $v }}{{ end }}{{ end }}'\''{{println}}
        {{- end }}{{ end -}}
    ' | grep "^MYSQL_"
)"

## sub-command execution
case "${WARDEN_PARAMS[0]}" in
    connect)
        "${WARDEN_DIR}/bin/warden" env exec db \
            mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --database="${MYSQL_DATABASE}" "${WARDEN_PARAMS[@]:1}" "$@"
        ;;
    import)
        LC_ALL=C sed -E 's/DEFINER[ ]*=[ ]*`[^`]+`@`[^`]+`/DEFINER=CURRENT_USER/g' \
            | LC_ALL=C sed -E '/\@\@(GLOBAL\.GTID_PURGED|SESSION\.SQL_LOG_BIN)/d' \
            | "${WARDEN_DIR}/bin/warden" env exec -T db \
            mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --database="${MYSQL_DATABASE}" "${WARDEN_PARAMS[@]:1}" "$@"
        ;;
    dump)
            "${WARDEN_DIR}/bin/warden" env exec -T db \
            mysqldump -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" "${WARDEN_PARAMS[@]:1}" "$@"
        ;;
    tunnel)
            DBTPORT=63306
            DB_CONTAINER_HOST=$(docker inspect $DB_CONTAINER --format='{{.Name}}'| cut -c2- )
            
            INUSE=`lsof -i -P -n | grep $DBTPORT || true`
            while [ ! -z "$INUSE" ]
            do
                DBTPORT=$((DBTPORT+1));
                INUSE=`lsof -i -P -n | grep $DBTPORT || true`
            done
            echo -e "\033[33m$DB_CONTAINER_HOST: mysql://$MYSQL_USER:$MYSQL_PASSWORD@127.0.0.1:$DBTPORT/magento\033[0m"
            echo "$WARDEN_HOME_DIR/dbtunnel_$DBTPORT.sock"
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -f -S $WARDEN_HOME_DIR/dbtunnel_$DBTPORT.sock -N -T -M  -L $DBTPORT:$DB_CONTAINER_HOST:3306 user@tunnel.warden.test -p2222 -i $WARDEN_HOME_DIR/tunnel/ssh_key > /dev/null 2>&1 
            read -p "Press any key to close tunnel... " -n1 -s
            printf "\nClosing DB Tunnel\n"
            ssh -S $WARDEN_HOME_DIR/dbtunnel_$DBTPORT.sock -O exit tunnel.warden.test > /dev/null 2>&1
        ;;
    *)
        fatal "The command \"${WARDEN_PARAMS[0]}\" does not exist. Please use --help for usage."
        ;;
esac
