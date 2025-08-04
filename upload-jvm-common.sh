#!/usr/bin/env bash
#
# This script uploads the JVM common to S3. This script uses the `stoml` tool to
# parse a TOML file in bash. You can get it here:
# https://github.com/freshautomations/stoml.
#
# You should define three environment variables for the S3 upload to work:
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
#   - AWS_SESSION_TOKEN
#
# If you need some credentials, go here:
# https://console.aws.amazon.com/iam/home?region=eu-central-1#/users
#
# For the authorization, you need to click "Attach existing policies directly"
# and chose `put-buildpacks-repository`.

set -e
# set -x

print_usage() {
  echo "Synopsis:" >&2
  echo "$0" >&2
}

if [[ $# -gt 0 ]]; then
  print_usage
  exit 1
fi

cur_dir="$(cd "$(dirname "${0}")" && pwd)"
cd "${cur_dir}"

archive_name="jvm-common.tar.xz"

echo "---> Creating the archive ${archive_name}"

jvm_common_dir="$(mktemp --tmpdir=/tmp --directory jvm-common-XXXX)"
ignore_files="$(./tools/stoml ./buildpack.toml publish.Ignore.files)"
exclude_opts="--exclude=tools"

for f in ${ignore_files}; do
  exclude_opts="${exclude_opts} --exclude=${f}"
done

# We use rsync instead of cp to copy files excluding some other files
rsync --recursive --perms --times --group --owner "${exclude_opts}" ./* "${jvm_common_dir}"

if [[ $? -ne 0 ]]; then
  echo "Fail to copy the files to the temporary directory (${jvm_common_dir})" >&2
  exit 1
fi

tar --create --xz --file "${archive_name}" --directory "${jvm_common_dir}" .

if [[ $? -ne 0 ]]; then
  echo "Error when creating the archive" >&2
  exit 1
fi

echo "---> Archive created"

which s3cmd >/dev/null ||
  echo "s3cmd is not available in your PATH" >&2 ||
  echo "Archive not uploaded to S3" >&2 ||
  exit 1

s3_bucket="buildpacks-repository"

echo "---> Uploading ${archive_name} to S3 (${s3_bucket})"

s3cmd \
	--access_key="${AWS_ACCESS_KEY_ID}" \
	--secret_key="${AWS_SECRET_ACCESS_KEY}" \
	--access_token="${AWS_SESSION_TOKEN}" \
	--acl-public --quiet \
	put "${archive_name}" \
	"s3://${s3_bucket}/"

if [[ $? -ne 0 ]]; then
  echo "Error uploading the archive to S3" >&2
  exit 1
fi

echo "---> Deleting the temporary files"
rm -r "${jvm_common_dir}" "${archive_name}"
