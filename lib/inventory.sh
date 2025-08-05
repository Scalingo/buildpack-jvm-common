#!/usr/bin/env bash

JVM_COMMON_DIR="${JVM_COMMON_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)}"

# Query the OpenJDK inventory, returning an JSON object describing the release.
#
# Exits with a non-zero exit code if no matching OpenJDK release could be found.
#
# Usage:
# ```
# inventory::query "zulu-21" "heroku-24" | jq -r ".url"
# ```
inventory::query() {
	local raw_version_string="${1}"
	local stack="${2}"
	local inventory_file="inventory.json"

	# Inventory file is done for heroku,so we have to update $stack:
	stack="${stack/scalingo/heroku}"
	# Remove '-minimal' from $stack:
	stack="${stack/-minimal/}"

	# We keep a specific inventory file for scalingo-20
	# The regular inventory file is updated, the -20 one is not.
	if [ "${stack}" = "heroku-20" ]; then
		inventory_file="inventory-20.json"
	fi

	local default_distribution="zulu"

	read -d '' -r INVENTORY_QUERY <<-'INVENTORY_QUERY'
		($raw_version_string | capture("((?<stack>[^-]*?)-)?(?<version>.*$)")) as $parsed_raw_version_string |
		(.version_aliases[$parsed_raw_version_string.version] // $parsed_raw_version_string.version) as $version |
		($parsed_raw_version_string.stack // $default_distribution) as $distribution |
		.artifacts[] | select(.version == $version and .metadata.distribution == $distribution and .arch == "amd64" and .os == "linux" and ((.metadata.cedar_stacks // []) | index($stack) != null))
	INVENTORY_QUERY

	jq <"${JVM_COMMON_DIR}/${inventory_file}" \
		--exit-status \
		--compact-output \
		--arg raw_version_string "${raw_version_string}" \
		--arg default_distribution "${default_distribution}" \
		--arg stack "${stack}" \
		"${INVENTORY_QUERY}"
}
