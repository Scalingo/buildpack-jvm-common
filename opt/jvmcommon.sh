#!/usr/bin/env bash

calculate_java_memory_opts() {
  local opts=${1:-""}
  local memory_limit_file='/sys/fs/cgroup/memory/memory.limit_in_bytes'

  if [[ -f "${memory_limit_file}" ]]; then
    # XX:XICompilerCount=2 is the minimum value

    case $( cat "${memory_limit_file}" ) in
      268435456)   # 256M   - S
        echo "$opts -Xmx160m -Xss512k --XXCICompilerCount=2"
        return 0
        ;;
      536870912)   # 512M   - M
        echo "$opts -Xmx300m -Xss512k -XX:CICompilerCount=2"
        return 0
        ;;
      1073741824)  # 1024M  - L
        echo "$opts -Xmx671m -XX:CICompilerCount=2"
        return 0
        ;;
      2147483648)  # 2048M  - XL
        echo "$opts -Xmx1536m -XX:CICompilerCount=2"
        return 0
        ;;
     esac
  fi

  # In all other cases, rely on JVM ergonomics for other container sizes, but
  # increase the maximum RAM percentage from 25% (Java's default) to 80%.
  echo "$opts -XX:MaxRAMPercentage=80.0"
}

if [[ -d $HOME/.jdk ]]; then
  export JAVA_HOME="$HOME/.jdk"
  export PATH="$HOME/.scalingo/bin:$JAVA_HOME/bin:$PATH"
else
  JAVA_HOME="$(realpath "$(dirname "$(command -v java)")/..")"
  export JAVA_HOME
fi

if [[ -d "$JAVA_HOME/jre/lib/amd64/server" ]]; then
  export LD_LIBRARY_PATH="$JAVA_HOME/jre/lib/amd64/server:$LD_LIBRARY_PATH"
elif [[ -d "$JAVA_HOME/lib/server" ]]; then
  export LD_LIBRARY_PATH="$JAVA_HOME/lib/server:$LD_LIBRARY_PATH"
fi

if [ -f "$JAVA_HOME/release" ] && grep -q '^JAVA_VERSION="1[0-9]' "$JAVA_HOME/release"; then
  default_java_mem_opts="$(calculate_java_memory_opts "-XX:+UseContainerSupport")"
else
  default_java_mem_opts="$(calculate_java_memory_opts | sed 's/^ //')"
fi

if echo "${JAVA_OPTS:-}" | grep -q "\-Xmx"; then
  export JAVA_TOOL_OPTIONS=${JAVA_TOOL_OPTIONS:-"-Dfile.encoding=UTF-8"}
else
  default_java_opts="${default_java_mem_opts} -Dfile.encoding=UTF-8"
  export JAVA_OPTS="${default_java_opts} ${JAVA_OPTS:-}"
  if echo "${CONTAINER}" | grep -vq '^one-off-.*$'; then
    export JAVA_TOOL_OPTIONS="${default_java_opts} ${JAVA_TOOL_OPTIONS:-}"
  fi
  if echo "${CONTAINER}" | grep -q '^web-.*$'; then
    echo "Setting JAVA_TOOL_OPTIONS defaults based on dyno size. Custom settings will override them."
  fi
fi
