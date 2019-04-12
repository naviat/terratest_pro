#!/usr/bin/env bash

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /user-data/mock-user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

source "/opt/influxdb-commons/influxdb-common.sh"
source "/opt/influxdb-commons/mount-volume.sh"

function mount_volumes {
  local -r volume_device_name="$1"
  local -r volume_mount_point="$2"
  local -r volume_owner="$3"

  echo "Mounting EBS Volume for meta, data, wal and hh directories"
  mount_volume "$volume_device_name" "$volume_mount_point" "$volume_owner"
}

function run_influxdb {
  local -r asg_name="$1"
  local -r aws_region="$2"
  local -r license_key="$3"
  local -r shared_secret="$4"
  local -r volume_device_name="$5"
  local -r volume_mount_point="$6"
  local -r volume_owner="$7"
  local -r hostname=$(get_node_hostname)

  mount_volumes "$volume_device_name" "$volume_mount_point" "$volume_owner"

  local -r meta_dir="$volume_mount_point/var/lib/influxdb/meta"
  local -r data_dir="$volume_mount_point/var/lib/influxdb/data"
  local -r wal_dir="$volume_mount_point/var/lib/influxdb/wal"
  local -r hh_dir="$volume_mount_point/var/lib/influxdb/hh"

  "/opt/influxdb/bin/run-influxdb" \
    --hostname "$hostname" \
    --node-type "meta" \
    --meta-asg-name "$asg_name" \
    --data-asg-name "$asg_name" \
    --region "$aws_region" \
    --auto-fill "<__HOST_NAME__>=$hostname" \
    --auto-fill "<__LICENSE_KEY__>=$license_key" \
    --auto-fill "<__SHARED_SECRET__>=$shared_secret" \
    --auto-fill "<__META_DIR__>=$meta_dir"

  "/opt/influxdb/bin/run-influxdb" \
    --hostname "$hostname" \
    --node-type "data" \
    --meta-asg-name "$asg_name" \
    --data-asg-name "$asg_name" \
    --region "$aws_region" \
    --auto-fill "<__HOST_NAME__>=$hostname" \
    --auto-fill "<__LICENSE_KEY__>=$license_key" \
    --auto-fill "<__SHARED_SECRET__>=$shared_secret" \
    --auto-fill "<__META_DIR__>=$meta_dir" \
    --auto-fill "<__DATA_DIR__>=$data_dir" \
    --auto-fill "<__WAL_DIR__>=$wal_dir" \
    --auto-fill "<__HH_DIR__>=$hh_dir"
}

function run_telegraf {
  local -r influxdb_url="$1"
  local -r database_name="$2"

  "/opt/telegraf/bin/run-telegraf" \
    --auto-fill "<__INFLUXDB_URL__>=$influxdb_url" \
    --auto-fill "<__DATABASE_NAME__>=$database_name"
}

function run_kapacitor {
  local -r hostname="$1"
  local -r influxdb_url="$2"
  local -r volume_device_name="$3"
  local -r volume_mount_point="$4"
  local -r volume_owner="$5"

  mount_volumes "$volume_device_name" "$volume_mount_point" "$volume_owner"

  "/opt/kapacitor/bin/run-kapacitor" \
    --auto-fill "<__HOST_NAME__>=$hostname" \
    --auto-fill "<__STORAGE_DIR__>=$volume_mount_point" \
    --auto-fill "<__INFLUXDB_URL__>=$influxdb_url"
}

function run_chronograf {
  local -r host="$1"
  local -r port="$2"

  "/opt/chronograf/bin/run-chronograf" \
    --auto-fill "<__HOST__>=$host" \
    --auto-fill "<__PORT__>=$port"
}

run_influxdb \
  "${cluster_asg_name}" \
  "${aws_region}" \
  "${license_key}" \
  "${shared_secret}" \
  "${influxdb_volume_device_name}" \
  "${influxdb_volume_mount_point}" \
  "${influxdb_volume_owner}"

run_telegraf \
  "${influxdb_url}" \
  "${database_name}"

run_kapacitor \
  "${hostname}" \
  "${influxdb_url}" \
  "${kapacitor_volume_device_name}" \
  "${kapacitor_volume_mount_point}" \
  "${kapacitor_volume_owner}"

run_chronograf \
  "${host}" \
  "${port}"
