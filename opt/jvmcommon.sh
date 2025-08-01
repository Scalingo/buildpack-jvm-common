#!/usr/bin/env bash

export JAVA_HOME="${HOME}/.jdk"
export PATH="${HOME}/.scalingo/bin:${PATH}"
export PATH="${JAVA_HOME}/bin:${PATH}"

# Path is OpenJDK version dependent
for path in "${JAVA_HOME}/lib/server" "${JAVA_HOME}/jre/lib/amd64/server"; do
	if [[ -d "${path}" ]]; then
		export LD_LIBRARY_PATH="${path}${LD_LIBRARY_PATH:+":"}${LD_LIBRARY_PATH:-}"
	fi
done

jvm_options() {
	local flags=(
		# Default to UTF-8 encoding when no charset is specified for methods in the Java standard library.
		# This makes programs more predictable and has been a default on Heroku for a many years. For OpenJDK >= 18,
		# setting this is technically no longer necessary as it is the default.
		# See JEP-400 for details: https://openjdk.org/jeps/400
		"-Dfile.encoding=UTF-8"
	)

	local memory_limit_file='/sys/fs/cgroup/memory/memory.limit_in_bytes'

	if [[ -f "${memory_limit_file}" ]]; then
		local memory_limit
		memory_limit="$( cat "${memory_limit_file}" )"

		# Ignore values above 1TiB RAM, since when using cgroups v1 the limits file reports a
		# bogus value of thousands of TiB RAM when there is no container memory limit set.
		if ((memory_limit > 1099511627776)); then
			unset memory_limit
		fi
	fi

	if [[ -n "${memory_limit}" ]]; then
		# The JVM tries to automatically detect the amount of available RAM for its heuristics. However,
		# the detection has proven to be sometimes inaccurate in certain configurations.
		# MaxRAM is used by the JVM to derive other flags from it.
		flags+=("-XX:MaxRAM=${memory_limit}")
	fi

	case "${memory_limit:-}" in
		268435456)   # 256M   - S
			flags+=("-Xmx160m" "-Xss512k" "-XX:CICompilerCount=2")
			;;
		536870912)   # 512M   - M
			flags+=("-Xmx300m" "-Xss512k" "-XX:CICompilerCount=2")
			;;
		1073741824)  # 1024M  - L
			flags+=("-Xmx671m" "-XX:CICompilerCount=2")
			;;
		2147483648)  # 2048M  - XL
			flags+=("-Xmx1536m" "-XX:CICompilerCount=2")
			;;
		*)
			# In all other cases, rely on JVM ergonomics for other container sizes, but
			# increase the maximum RAM percentage from 25% (Java's default) to 80%.
			flags+=("-XX:MaxRAMPercentage=80.0")
			;;
	esac

	(
		IFS=" "
		echo "${flags[*]}"
	)
}

jvm_options="$(jvm_options)"
export JAVA_OPTS="${jvm_options}${JAVA_OPTS:+" "}${JAVA_OPTS:-}"


# FYI, at Heroku, one-offs have a process type starting with "run.*"
if ! [[ "${CONTAINER}" =~ ^one-off-.*$ ]]; then
	# Redirecting to stderr to avoid polluting the application's stdout stream. This is especially important for
	# MCP servers using the stdio transport: https://modelcontextprotocol.io/specification/2025-03-26/basic/transports#stdio
	echo "Setting JAVA_TOOL_OPTIONS defaults based on container size. Custom settings will override them." >&2
	export JAVA_TOOL_OPTIONS="${jvm_options}${JAVA_TOOL_OPTIONS:+" "}${JAVA_TOOL_OPTIONS:-}"
fi
