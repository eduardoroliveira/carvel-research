msg=`hostname`
msg="$msg $1"
while [ true ]; do
  echo "$(date "+%Y/%m/%d %H:%M:%S") $msg"
  sleep 2
done
