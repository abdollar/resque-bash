#!/bin/bash

# note that this script assumes it has been placed in the rails application bin or script directory
NAMESPACE="resque"
ENVIRONMENT=${RAILS_ENV:=development}
FILE_PATH=$(cd `/usr/bin/dirname $0`; pwd -P)
QUEUE="critical"
CLASS="fetch"
ARGS="$(/bin/date '+%s')"
WORKER="$(/bin/hostname):$$:${QUEUE}"

usage()
{
cat << EOF
usage: $0 options

This script places a job onto a resque queue

OPTIONS:
  -h      Show this message
  -s      Set the server (default is localhost or settings based on RAILS_ENV and config/resque.yml
  -p      Server root port (default is 6379 or settings based on RAILS_ENV and config/resque.yml
  -q      Resque queue name (default is critical)
  -c      Class name for the resque queue (default is critical)
  -a      Args for the class (default is current time in seconds)
EOF
}

while getopts ":h:s:p:q:c:e:a" opt; do
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
    \?)
      usage
      echo "Invalid option: -$OPTARG" >&2
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

/usr/local/bin/redis-cli -h $HOST -p $PORT SADD "${NAMESPACE}:queues" "${QUEUE}"
/usr/local/bin/redis-cli -h $HOST -p $PORT RPUSH "${NAMESPACE}:queue:${QUEUE}" "{\"class\":\"${CLASS}\",\"args\":${ARGS}}"
echo "Done."

# value = Abduls-MacBook-Pro-2.local:91632:live_channel_batch,custom_mailer,date_and_time,mini_queue,pub_sub,async_work,instant
/usr/local/bin/redis-cli -h $HOST -p $PORT SADD "${NAMESPACE}:workers" "${WORKER}"

# working on this queue item?? CLASS should be same as above
/usr/local/bin/redis-cli -h $HOST -p $PORT SET "${NAMESPACE}:worker:${WORKER}" "{\"queue\":\"${QUEUE}\",\"run_at\":\"${ARGS}\",\"payload\":\"${ARGS}\"}"

# resque:worker:Abduls-MacBook-Pro-2.local:91632:live_channel_batch,custom_mailer,date_and_time,mini_queue,pub_sub,async_work,instant:started
/usr/local/bin/redis-cli -h $HOST -p $PORT SET "${NAMESPACE}:worker:${WORKER}:started" "${ARGS}"
#while true; do
  sleep 30
#done

function on_exit()
{
  /usr/local/bin/redis-cli -h $HOST -p $PORT SREM "${NAMESPACE}:workers" "${WORKER}"
  /usr/local/bin/redis-cli -h $HOST -p $PORT DEL "${NAMESPACE}:worker:${WORKER}" 
  /usr/local/bin/redis-cli -h $HOST -p $PORT DEL "${NAMESPACE}:worker:${WORKER}:started" "${ARGS}"
}

trap on_exit EXIT

