#!/bin/bash

# If you need more debug play with these variables:
# export NO_STARTUP_LOGS=
# export SHELL_DEBUG=1
# export DEBUG=1
# start by the first one, then try the others

set -e
readlinkf() {
    if ( uname | grep -E -iq "darwin|bsd" );then
        if ( which greadlink 2>&1 >/dev/null );then
            greadlink -f "$@"
        elif ( which perl 2>&1 >/dev/null );then
            perl -MCwd -le 'print Cwd::abs_path shift' "$@"
        elif ( which python 2>&1 >/dev/null );then
            python -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$@"
        fi
    else
        readlink -f "$@"
    fi
}
THISSCRIPT=$0
W="$(dirname $(readlinkf $0))"

SHELL_DEBUG=${SHELL_DEBUG-${SHELLDEBUG}}
if [[ -n $SHELL_DEBUG ]];then set -x;fi

shopt -s extglob

ENV_FILES="${ENV_FILES:-.env docker.env}"
source_envs() {
    set -o allexport
    for i in $ENV_FILES;do
        if [ -e "$i" ];then
            while read vardef;do
                var="$(echo "$vardef" | awk -F= '{print $1}')"
                val="$(echo "$vardef" | awk '{gsub(/^[^=]+=/, "");print;}')"
                if ( echo "$val" | grep -E -q "'" )  || ! ( echo "$val" | grep -E -q '"' ) ;then
                    eval "$var=\"$val\""
                else
                    eval "$var='$val'"
                fi
            done < <( \
                cat $i| grep -E -v "^\s*#" | grep -E "^([a-zA-Z0-9_]+)=" )
        fi
    done
    set +o allexport
}
source_envs

VENV=../venv
APP={{cookiecutter.app_type}}
APP_USER=${APP_USER:-${APP}}
APP_CONTAINER=${APP_CONTAINER:-${APP}}
APP_CONTAINERS="^($APP_CONTAINER)"
DEBUG=${DEBUG-}
NO_BACKGROUND=${NO_BACKGROUND-}
BUILD_PARALLEL=${BUILD_PARALLEL-1}
BUILD_CONTAINERS="$APP_CONTAINER{%-if not cookiecutter.remove_cron%} cron{%endif%}"
EDITOR=${EDITOR:-vim}
DIST_FILES_FOLDERS=". src/*/settings"
# support both former $CONTROL_COMPOSE_FILES & $COMPOSE_FILE
DEFAULT_CONTROL_COMPOSE_FILES="${DEFAULT_CONTROL_COMPOSE_FILES-docker-compose.yml docker-compose-dev.yml}"
if [[ -n "$FORCE_OSX_SYNC" ]]; then
    DEFAULT_CONTROL_COMPOSE_FILES="$DEFAULT_CONTROL_COMPOSE_FILES docker-compose-darwin.yml"
fi
CONTROL_COMPOSE_FILES="${CONTROL_COMPOSE_FILES:-$DEFAULT_CONTROL_COMPOSE_FILES}"
COMPOSE_COMMAND=${COMPOSE_COMMAND:-docker-compose}
NO_DEVELOP=${NO_DEVELOP-}
# special case: be sure to define some docker internal variables but let them overridable through .env
export DOCKER_BUILDKIT="${DOCKER_BUILDKIT-1}"
export COMPOSE_DOCKER_CLI_BUILD="${COMPOSE_DOCKER_CLI_BUILD-1}"
export BUILDKIT_PROGRESS="${BUILDKIT_PROGRESS-plain}"
export BUILDKIT_INLINE_CACHE="${BUILDKIT_INLINE_CACHE-1}"

join_by() { local IFS="$1"; shift; echo "$*"; }

set_dc() {
    export COMPOSE_FILE_RUN="${@:-${COMPOSE_FILE-${CONTROL_COMPOSE_FILES// /:}}}"
    export COMPOSE_FILE="${COMPOSE_FILE_RUN}"
    DC="${COMPOSE_COMMAND}";DCB="${DC}"
    if [[ -z $COMPOSE_FILE ]];then
        export COMPOSE_FILE_BUILD="docker-compose-build.yml"
    else
        export COMPOSE_FILE_BUILD="$COMPOSE_FILE:docker-compose-build.yml"
    fi
    if (echo "$COMPOSE_FILE"|grep -q  -- -dev );then
        export COMPOSE_FILE_BUILD="$COMPOSE_FILE_BUILD:docker-compose-build-dev.yml"
    fi
    export CONTROL_COMPOSE_FILES="${COMPOSE_FILE//:/ }"
}

log(){ echo "$@">&2;}

die(){ log $@;exit 1; }

vv() { log "$@";"$@";}

debug() { if [[ -n $DEBUG ]];then log "$@";fi }

dvv() { if [[ -n $DEBUG ]];then log "$@";fi;"$@";}

#  up_corpusops: update corpusops
do_up_corpusops() {
    local/corpusops.bootstrap/bin/install.sh -C
}

_shell() {
    local pre=""
    local container="$1" user="$2" run_mode="$3"
    shift;shift;shift
    local services_ports=${services_ports-}
    local use_aliases=${use_aliases-}
    local bargs="${@:-shell}"
    local DOCKER_SHELL=${DOCKER_SHELL-}
    local SHELL_USER=${user-${SHELL_USER}}
    local run_mode_args=""
    local initsh=""
    if ( echo $container |grep -E -q "$APP_CONTAINERS" );then
        local initsh="/init.sh"
    fi
    if [[ "$run_mode" == "run" ]];then
        run_mode_args="$run_mode_args --rm --no-deps"
        if [[ -n "$use_aliases" ]];then
            run_mode_args="$run_mode_args --use-aliases"
        fi
        if [[ -n "$services_ports" ]];then
            run_mode_args="$run_mode_args --service-ports"
        fi
    fi
    if [[ "$run_mode" == "dexec" ]];then
        set -- dvv docker exec -ti \
            -e TERM=$TERM -e COLUMNS=${COLUMNS:-80} -e LINES=${LINES:-40} \
            -e SHELL_USER=${SHELL_USER} \
            $container $bargs
    else
        set -- dvv do_dcompose \
            $run_mode $run_mode_args \
            -e TERM=$TERM -e COLUMNS=${COLUMNS:-80} -e LINES=${LINES:-40} \
            -e SHELL_USER=${SHELL_USER} \
            $container $initsh $bargs
    fi
    "$@"
}

#  dcompose $@: wrapper to docker-compose
do_dcompose() {
    set -- dvv $DC "$@"
    ( export COMPOSE_FILE="$COMPOSE_FILE_RUN" && debug "using COMPOSE_FILE=$COMPOSE_FILE" && "$@" )
}

#  dbcompose $@: wrapper to docker-compose with build compose files set
do_dbcompose() {
    set -- dvv $DCB "$@"
    ( export COMPOSE_FILE="$COMPOSE_FILE_BUILD" && debug "using COMPOSE_FILE=$COMPOSE_FILE" && "$@" )
}

#  mysql $@: wrapper to mysql interpreter
do_mysql() {
    set -x
    cmd='do_dcompose exec db sh -ec "mysql --password=\$MYSQL_PASSWORD --user=\$MYSQL_USER \$MYSQL_DATABASE'
    cli=( "$@" )
    for var in "${cli[@]}";do cmd="$cmd $(printf %q "$var")";done
    eval $cmd'"'
}

#  psql $@: wrapper to psql interpreter
do_psql() {
    cmd='do_dcompose exec db bash -ec "PGUSER=\$POSTGRES_USER PGPASSWORD=\$PGPASSWD PGHOST=\$POSTGRES_HOST PGPORT=\$POSTGRES_PORT PGDATABASE=\$POSTGRES_DB psql'
    cli=( "$@" )
    for var in "${cli[@]}";do cmd="$cmd $(printf %q "$var")";done
    eval $cmd'"'
}

#  ----
#  [services_ports=1] usershell $user [$args]: open shell inside $CONTAINER as $APP_USER using docker-compose run
#       APP_USER={{cookiecutter.app_type}} ./control.sh usershell ls /
#       APP_USER=root CONTAINER={{cookiecutter.cache_system}} ./control.sh usershell ls /
#       if services_ports is set, network alias will be set (--services-ports docker-compose run flag)
do_usershell() { _shell "${CONTAINER:-$APP_CONTAINER}" "$APP_USER" run $@;}

#  [services_ports=1] shell [$args]: open root shell inside $CONTAINER using docker-compose run
#       if services_ports is set, network alias will be set (--services-ports docker-compose run flag)
#  ----
do_shell()     { _shell "${CONTAINER:-$APP_CONTAINER}" root      run $@;}

_exec() {
    local user="$2" container="$1";shift;shift
    _shell "$container" "$user" exec $@
}

#  userexec [$args]: exec command or make an interactive shell as $user inside running $CONTAINER using docker-compose exec
#       APP_USER={{cookiecutter.app_type}} ./control.sh userexec ls /
#       APP_USER=root APP_CONTAINER={{cookiecutter.cache_system}} ./control.sh userexec ls /
do_userexec() { _exec "${CONTAINER:-$APP_CONTAINER}" "$APP_USER" $@;}

#  exec [$args]: exec command or shell as root inside running \$CONTAINER using docker-compose exec
#  ----
do_exec()     { _exec "${CONTAINER:-$APP_CONTAINER}" root      $@;}

_dexec() {
    local user="$2" container="$1";shift;shift
    if [[ -z $container ]];then
        container=$(docker ps -a|grep _${APP_CONTAINER}_|awk '{print $1}')
    fi
    if [[ -z $container ]];then
        echo "Provide container to execute into (docker ps -a)" >&2
        exit 1
    fi
    _shell "$container" "$user" dexec $@
}

#  duserexec $container  [$args]: exec command or make an interactive shell as $user inside running $APP_CONTAINER using docker exec
#       APP_USER={{cookiecutter.app_type}} ./control.sh duserexec -> run interactive shell inside default CONTAINER
#       APP_USER={{cookiecutter.app_type}} ./control.sh duserexec foo123 -> run interactive shell inside foo123 CONTAINER
#       APP_USER={{cookiecutter.app_type}} ./control.sh duserexec plone_123 ls / -> run comand inside foo123 CONTAINER
do_duserexec() {
    local container="${1-}";if [[ -n "${1-}" ]];then shift;fi
    _dexec "${container}" "$APP_USER" $@;
}

#  dexec $container  [$args]: exec command or make an interactive shell as root inside running $APP_CONTAINER using docker exec
#  ----
do_dexec() {
    local container="${1-}";if [[ -n "${1-}" ]];then shift;fi
    _dexec "${container}" root      $@;
}

#  install_docker: install docker and docker-compose on ubuntu
do_install_docker() {
    vv .ansible/scripts/download_corpusops.sh
    vv .ansible/scripts/setup_corpusops.sh
    vv local/*/bin/cops_apply_role --become \
        local/*/*/corpusops.roles/services_virt_docker/role.yml
}

#  pull [$args]: pull stack container images
do_pull() {
    vv do_dcompose pull $@
}


#  ps [$args]: ps
do_ps() {
    local bargs=$@
    set -- vv do_dcompose ps
    $@ $bargs
}

#  up [$args]: start stack
do_up() {
    local bargs=$@
    set -- vv do_dcompose up
    if [[ -z $NO_BACKGROUND ]];then bargs="-d $bargs";fi
    $@ $bargs
}


#  run [$args]: run stack
do_run() {
    local bargs=$@
    set -- vv do_dcompose run
    $@ $bargs
}

#  rm [$args]: rm stack
do_rm() {
    local bargs=$@
    set -- vv do_dcompose rm
    $@ $bargs
}

#  down [$args]: down stack
do_down() {
    local bargs=$@
    set -- vv do_dcompose down
    $@ $bargs
}

#  stop [$args]: stop
do_stop() {
    local bargs=$@
    set -- vv do_dcompose stop
    $@ $bargs
}

#  stop_containers [$args]: stop containers (app_container by default)
stop_containers() {
    for i in ${@:-$APP_CONTAINER};do do_dcompose stop $i;done
}

#  fg: launch app container in foreground (using entrypoint)
do_fg() {
    stop_containers
    vv do_dcompose run --rm --no-deps --use-aliases --service-ports -e IMAGE_MODE=fg $APP_CONTAINER $@
}

#  build [$args]: rebuild app containers ($BUILD_CONTAINERS)
do_build() {
    local bargs="$@" bp=""
    if [[ -n $BUILD_PARALLEL ]];then
        bp="${bp} --parallel"
    fi
    if [[ -n $BUILDKIT_INLINE_CACHE ]];then
        bp="${bp} --build-arg BUILDKIT_INLINE_CACHE=\"${BUILDKIT_INLINE_CACHE}\""
    fi
    set -- vv do_dbcompose build $bp
    if [[ -z "$bargs" ]];then
        for i in $BUILD_CONTAINERS;do
            $@ $i
        done
    else
        $@ $bargs
    fi
}

#  buildimages: alias for build
do_buildimages() {
    do_build "$@"
}

#  build_images: alias for build
do_build_images() {
    do_build "$@"
}

#  usage: show this help
do_usage() {
    echo "$0:"
    # Show autodoc help
    awk '{ if ($0 ~ /^#[^!]/) { \
                gsub(/^#/, "", $0); print $0 } }' "$THISSCRIPT"
    echo " Defaults:
        \$BUILD_CONTAINERS (default: $BUILD_CONTAINERS)
        \$APP_CONTAINER: (default: $APP_CONTAINER)
        \$APP_USER: (default: $APP_USER)
    "
}

#  init: copy base configuration files from defaults if not existing
do_init() {
    for d in  $( \
        find $DIST_FILES_FOLDERS -mindepth 1 -maxdepth 1 -name "*.dist" -type f )
    do
        i="$(dirname $d)/$(basename $d .dist)"
        if [ ! -e $i ];then
            cp -fv "$d" "$i"
        else
            if ! ( diff -Nu "$d" "$i" );then
                echo "Press enter to continue";read -t 120
            fi
        fi
        $EDITOR $i
    done
}

#  yamldump [$file]: dump yaml file with anchors resolved
do_yamldump() {
    local bargs=$@
    if [ -e local/corpusops.bootstrap/venv/bin/activate ];then
        . local/corpusops.bootstrap/venv/bin/activate
    fi
    set -- .ansible/scripts/yamldump.py
    $@ $bargs
}

# {{cookiecutter.app_type.upper()}} specific
#  python: enter python interpreter
do_python() { do_usershell $VENV/bin/python $@; }

#  manage [$args]: run manage.py commands
do_manage() { do_python manage.py $@; }

#  runserver [$args]: alias for fg
do_runserver() { do_fg "$@"; }

do_run_server() { do_runserver $@; }

#  tests [$tests]: run tests
do_test() { stop_containers && do_dcompose run -e COLUMNS=${COLUMNS:-80} -e LINES=${LINES:-40} --rm --entrypoint /app/init/init.sh plone tox --direct-yolo -e ${@:-tests}; }

do_tests() { do_test $@; }

#  linting: run linting tests
do_linting() { do_test linting; }

#  coverage: run coverage tests
do_coverage() { do_test coverage; }

#  open_perms_valve: Give the host user rights to edit most common files inside the container
#                    which are generally mounted as docker volumes from the host via posix ACLs
#                    This won't work on OSX for now.
do_open_perms_valve() {
    SUPEREDITOR="${SUPEREDITOR:-$(id -u)}"
    OPENVALVE_SOURCE="${OPENVALVE_SOURCE:-${W}}"
    OPENVALVE_INTERNAL_UID="${OPENVALVE_INTERNAL_UID-1000}"
    DEFAULT_OPENVALVE_ACL="u:$SUPEREDITOR:rwx,u:$OPENVALVE_INTERNAL_UID:rwx,d:u:$SUPEREDITOR:rwx,d:u:$OPENVALVE_INTERNAL_UID:rwx"
    OPENVALVE_ACL="${OPENVALVE_ACL:-$DEFAULT_OPENVALVE_ACL}"
    dvv do_dcompose run --no-deps --rm \
        -v "$OPENVALVE_SOURCE:/openvalve" \
        -e "SUPEREDITOR=$SUPEREDITOR" \
        -e "OPENVALVE_ACL=$OPENVALVE_ACL" \
        --entrypoint sh $APP_CONTAINER \
        -exc \
        'if ! ( setfacl --version >/dev/null 2>&1 );then \
            if ( apt --version >/dev/null 2>&1   );then apt update -y && apt install -y acl; \
            elif ( apk --version >/dev/null 2>&1 );then apk update && apk add -y acl;fi \
        fi\
        && setfacl -R -m $OPENVALVE_ACL /openvalve'
}



#  get_container_code: refresh local/app with parts of the container files to help IDEs to do their completion job
do_get_container_code() {
    dvv do_dcompose run --no-deps --rm \
        -v $W/local/app:/output \
        --entrypoint bash $APP_CONTAINER \
        -ec '\
        log() { echo "$@">&2;}
        vv() { log "$@";"$@"; }
        if ! ( rsync --version &>/dev/null) ;then vv apt install -y rsync;fi
        for i in venv;do \
            vv rsync -ArptgoD -L --numeric-ids --delete --force --ignore-errors \
                /app/$i/ /output/$(basename $i)/
        done'
    OPENVALVE_SOURCE="$W/local/app" do_open_perms_valve
}


#  vscode: launch vscode with current python path
do_vscode() {
    VSCODE_ARGS="${@:-$W}"
    get_container_code=
    if [ ! -e local/app/venv ];then
        get_container_code=1
    fi
    if [[ -n ${FORCE_CODE_REFRESH-} ]];then
        get_container_code=1
    fi
    if [[ -n ${get_container_code-} ]];then
        do_get_container_code
    fi
    sp=$(ls -d "$W/local/app/venv/lib/"python*"/site-packages")
    if [[ -n $PYTHONPATH ]];then
        export PYTHONPATH="$PYTHONPATH:$sp"
    else
        export PYTHONPATH="$sp"
    fi
    code $VSCODE_ARGS
}

#  [NO_BUILD=] do_make_docs: daemon to sync local files inside docker containers (volumes to be exact)
do_make_docs() {
    if [[ -z ${NO_BUILD-} ]];then COMPOSE_FILE_RUN="docs/docker-compose.yml:docs/docker-compose-build.yml" do_dcompose build docs;fi
    # by default container entrypoint sync data to output dir
    COMPOSE_FILE_RUN="docs/docker-compose.yml" do_dcompose run --rm \
        -e NO_INSTALL=${NO_INSTALL-1} \
        -e NO_BUILD=${NO_BUILD-} \
        -e NO_INIT=${NO_HTML-} \
        -e NO_CLEAN=${NO_CLEAN-} \
        -e HOST_USER_UID=$(id -u) \
        -e DEBUG=${DEBUG-} \
        docs "$@"
}

#  doc: generate documentation
do_doc() {
    do_make_docs "$@"
}
{%- if cookiecutter.with_bundled_front %}

#  gen_js_conf: generate JS configs
do_gen_js_conf() {
    docker run --rm -v $(pwd):/a -e U_UID=$(id -u) corpusops/alpine-bare sh -c ': \
        && cd /a \
        && frep sys/etc/configs/frontend.config.json:frontend/public/frontend.config.json --overwrite \
        && chown $U_UID frontend/public/frontend.config.json'
}
{%- endif %}

do_main() {
    local args=${@:-usage}
    local actions="up_corpusops|shell|usage|install_docker|setup_corpusops|open_perms_valve|get_container_code|vscode"
    actions="$actions|yamldump|stop|usershell|exec|userexec|dexec|duserexec|dcompose|dbcompose|ps|psql|mysql"

    actions="$actions|init|up|fg|pull|build|buildimages|down|rm|run"
    actions_{{cookiecutter.app_type}}="runserver|tests|test|coverage|linting|manage|python"
    actions="$actions|doc|make_docs"
{%- if cookiecutter.with_bundled_front %}
    actions="$actions|gen_js_conf"
{% endif %}
    actions="@($actions|$actions_{{cookiecutter.app_type}})"
    action=${1-}
    if [[ -n $@ ]];then shift;fi
    set_dc
    case $action in
        $actions) do_$action "$@";;
        *) do_usage;;
    esac
}
cd "$W"
do_main "$@"
