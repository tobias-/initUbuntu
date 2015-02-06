#!/bin/bash -eu

# Mongo to S3 backup script.

packer=gzip
host=127.0.0.1
backup="s3://###############/backup/$(date +%Y)/$(date +%m)/"
region="us-east-1"
backup_dir="/log/backup"

export LC_ALL="en_US.UTF-8"


isExe() {
  for exe in "$@"; do
    if ! which "$exe" >/dev/null; then
      return 1
    fi
  done
  return 0
}


checkInstalledCorrectly() {
  if [ -f "$HOME/.s3cfg" ] && isExe s3cmd mongo mongodump $packer; then
    echo -n
  else
    echo "Needed components not found"
    echo "Install and configure s3cmd"
    echo "Installation:"
    echo "sudo yum install python-pip python-dateutil && sudo pip install s3cmd python-magic"
    echo "sudo apt-get install python-pip python-dateutil python-magic && sudo easy_install -U setuptools && sudo pip install s3cmd"
    echo "Configuration:"
    echo "(As the backup user) s3cmd --configure"
    exit 2
  fi
  if [ -d $backup_dir ] || [ -w $backup_dir ]; then
    echo -n
  else
    echo "Cannot write to $backup_dir"
  fi
}


# Check mongo state
checkMongoState() {
  myState="$(mongo --host $host --quiet --eval 'print(rs.status().myState)')"
  if [[ $myState != 2 ]]; then
    echo "$host is not a replica. Assuming this is a problem"
    exit 1
  fi
  primaryHealth="$(mongo --host $host --quiet --eval '
    var members = rs.status().members;
    for(var i in members) {
      var member = members[i];
      if (members.hasOwnProperty(i) && member.state === 1) {
        print((member.health === 1) ? "ok" : "down");
      }
    }')"
  if [[ ${primaryHealth} != ok ]]; then
    echo "Something wrong with primary. This is very weird."
    exit 2
  fi
}

checkMongoState
checkInstalledCorrectly

assert_uploaded() {
  size="$(s3cmd du "$1" | cut -d' ' -f1)"
  if [[ $size -lt 10000000 ]]; then
    echo "uploaded size ($size) is too small. Backup assumed failed"
    exit 3
  fi

}
date="$(date '+%Y%m%d-%H%M%S')"
dump_dir="${date}"

#
# The wait command after mongodump is used to avoid a bug that fails the dump. You can read more about the bug here:
#
# http://groups.google.com/group/mongodb-user/browse_thread/thread/ec96d71c14f7eb44
#

cd $backup_dir
mongodump --host $host --oplog -o "$dump_dir"
wait
echo "Backup dumped $dump_dir"
find "$dump_dir" -type f -print0 | xargs -0 $packer
echo "Packed $dump_dir"
s3_url="$backup"
s3cmd sync --region="$region" "$dump_dir"  "$s3_url"
echo "Backup uploaded correctly"
assert_uploaded "$s3_url$dump_dir"
rm -rf "$dump_dir"

