#!/bin/bash

# note that this script assumes it has been placed in the rails application bin or script directory
NAMESPACE="resque"
ENVIRONMENT=${RAILS_ENV:=development}
FILE_PATH=$(cd `/usr/bin/dirname $0`; pwd -P)
QUEUE="critical"
CLASS="fetch"
ARGS="$(/bin/date '+%s')"
WORKER="$(/bin/hostname):$$:${QUEUE}"
INTERVAL=0.5

usage()
{
cat << EOF
usage: $0 options

This script places a job onto a "resque" queue or it creates a worker to process those jobs

OPTIONS:
  -h      Show this message
  -s      Set the server (default is localhost or settings based on RAILS_ENV and config/resque.yml
  -p      Server root port (default is 6379 or settings based on RAILS_ENV and config/resque.yml
  -q      Resque queue name (default is critical)
  -c      Class name for the resque queue (default is critical)
  -a      Args for the class (default is current time in seconds)
  -w      This is a worker (default is to not work)
  -j      create a job
EOF
}

while getopts ":h:s:p:q:c:e:a:w:j" opt; do
  case $opt in
    h)
      usage
      exit 1
      ;;
    s)
      HOST=$OPTARG
      ;;
    p)
      PORT=$OPTARG
      ;;
    q)
      QUEUE=$OPTARG
      ;;
    c)
      CLASS=$OPTARG
      ;;
    e)
      ENVIRONMENT=$OPTARG
      ;;
    a)
      ARGS=$OPTARG
      ;;
    w)
      RWORKER=1
      ;;
    j)
      JOB=1
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done

if [ -e ${FILE_PATH}/../config/resque.yml ]
then
  HOST="$(awk -F ':' "/^${ENVIRONMENT}\:\s*/{ print \$2 }" ${FILE_PATH}/../config/resque.yml | sed 's/^[ \t]*//')"
  PORT="$(awk -F ':' "/^${ENVIRONMENT}\:\s*/{ print \$3 }" ${FILE_PATH}/../config/resque.yml | sed 's/^[ \t]*//')"
else
  HOST="localhost"
  PORT="6379"
fi

if [[ -z $JOB ]]
then
  : # no-op
else
  /usr/local/bin/redis-cli -h $HOST -p $PORT SADD "${NAMESPACE}:queues" "${QUEUE}"
  /usr/local/bin/redis-cli -h $HOST -p $PORT RPUSH "${NAMESPACE}:queue:${QUEUE}" "{\"class\":\"${CLASS}\",\"args\":${ARGS}}"
  echo "Done"
  exit
fi

/usr/local/bin/redis-cli -h $HOST -p $PORT SADD "${NAMESPACE}:workers" "${WORKER}"
/usr/local/bin/redis-cli -h $HOST -p $PORT SET "${NAMESPACE}:worker:${WORKER}" "{\"queue\":\"${QUEUE}\",\"run_at\":\"${ARGS}\",\"payload\":\"${ARGS}\"}"
/usr/local/bin/redis-cli -h $HOST -p $PORT SET "${NAMESPACE}:worker:${WORKER}:started" "${ARGS}"

function process_job()
{
  echo "job args:$1"
}

# process jobs
if [[ $RWORKER ]]
then
  echo "Done."
else
  while true; do
    ITEM=$(/usr/local/bin/redis-cli -h $HOST -p $PORT LPOP "${NAMESPACE}:queue:${QUEUE}")
    if [ "${ITEM}" != "" ]
    then
      process_job $ITEM
    fi
    sleep $INTERVAL
  done
fi

function on_exit()
{
  /usr/local/bin/redis-cli -h $HOST -p $PORT SREM "${NAMESPACE}:workers" "${WORKER}"
  /usr/local/bin/redis-cli -h $HOST -p $PORT DEL "${NAMESPACE}:worker:${WORKER}" 
  /usr/local/bin/redis-cli -h $HOST -p $PORT DEL "${NAMESPACE}:worker:${WORKER}:started" "${ARGS}"
}

trap on_exit EXIT

