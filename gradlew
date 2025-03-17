#!/bin/sh

# SPDX-License-Identifier: Apache-2.0
# Copyright © 2015-2021 the original authors.
# Licensed under the Apache License, Version 2.0
# See https://www.apache.org/licenses/LICENSE-2.0 for details

##############################################################################
# Gradle POSIX startup script
# Requires: POSIX-compliant shell with basic features (functions, expansions,
#           compound commands, built-ins like 'set' and 'ulimit')
#
# Generated from: https://github.com/gradle/gradle/blob/HEAD/platforms/jvm/plugins-application/src/main/resources/org/gradle/api/internal/plugins/unixStartScript.txt
##############################################################################

# Exit on any error
set -e

# Utility functions
warn() { printf '%s\n' "$*" >&2; }
die() { printf '\n%s\n\n' "$*" >&2; exit 1; }

# Resolve APP_HOME (handles symlinks)
resolve_app_home() {
    app_path=$0
    while [ -h "$app_path" ]; do
        ls=$(ls -ld "$app_path")
        link=${ls#*' -> '}
        case $link in
            /*) app_path=$link ;;
            *)  app_path=${app_path%"${app_path##*/}"}$link ;;
        esac
    done
    # Handle CDPATH by redirecting cd output
    APP_HOME=$(cd -P "${app_path%"${app_path##*/}"}" >/dev/null && pwd) || die "Failed to determine APP_HOME"
    # shellcheck disable=SC2034
    APP_BASE_NAME=${0##*/}
}

# Detect OS-specific environments
detect_os() {
    cygwin=false
    msys=false
    darwin=false
    nonstop=false
    case "$(uname)" in
        CYGWIN*)  cygwin=true ;;
        Darwin*)  darwin=true ;;
        MSYS*|MINGW*) msys=true ;;
        NONSTOP*) nonstop=true ;;
    esac
}

# Configure Java command
setup_java() {
    if [ -n "$JAVA_HOME" ]; then
        for java_path in "$JAVA_HOME/jre/sh/java" "$JAVA_HOME/bin/java"; do
            if [ -x "$java_path" ]; then
                JAVACMD=$java_path
                break
            fi
        done
        [ -z "$JAVACMD" ] && die "ERROR: JAVA_HOME is set to an invalid directory: $JAVA_HOME
Please set JAVA_HOME to a valid Java installation."
    else
        JAVACMD=java
        command -v java >/dev/null 2>&1 || die "ERROR: JAVA_HOME is not set and 'java' not found in PATH
Please set JAVA_HOME or ensure java is in PATH."
    fi
}

# Adjust file descriptor limits
adjust_fd_limits() {
    MAX_FD=maximum
    if ! "$cygwin" && ! "$darwin" && ! "$nonstop"; then
        case $MAX_FD in
            max*)
                # shellcheck disable=SC3045
                MAX_FD=$(ulimit -H -n 2>/dev/null) || warn "Could not query maximum file descriptor limit"
                ;;
        esac
        case $MAX_FD in
            ''|soft) ;;
            *)
                # shellcheck disable=SC3045
                ulimit -n "$MAX_FD" 2>/dev/null || warn "Could not set maximum file descriptor limit to $MAX_FD"
                ;;
        esac
    fi
}

# Convert paths for Windows environments
convert_paths() {
    if "$cygwin" || "$msys"; then
        APP_HOME=$(cygpath --path --mixed "$APP_HOME") || warn "Path conversion failed for APP_HOME"
        CLASSPATH=$(cygpath --path --mixed "$CLASSPATH") || warn "Path conversion failed for CLASSPATH"
        JAVACMD=$(cygpath --unix "$JAVACMD") || warn "Path conversion failed for JAVACMD"
        
        # Convert arguments
        for arg do
            if case $arg in -*) false;; /*) [ -e "${arg#/}" ];; *) false;; esac; then
                arg=$(cygpath --path --ignore --mixed "$arg") || warn "Failed to convert argument: $arg"
            fi
            shift; set -- "$@" "$arg"
        done
    fi
}

# Main execution
main() {
    resolve_app_home
    CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar
    
    detect_os
    setup_java
    adjust_fd_limits
    
    DEFAULT_JVM_OPTS='"-Xmx64m" "-Xms64m"'
    command -v xargs >/dev/null 2>&1 || die "xargs is not available"
    
    convert_paths
    
    # Build command arguments
    set -- \
        "-Dorg.gradle.appname=$APP_BASE_NAME" \
        -classpath "$CLASSPATH" \
        org.gradle.wrapper.GradleWrapperMain \
        "$@"
    
    # Process JVM options and execute
    eval "set -- $(
        printf '%s\n' "$DEFAULT_JVM_OPTS $JAVA_OPTS $GRADLE_OPTS" |
        xargs -n1 |
        sed 's/[^-[:alnum:]+,./:=@_]/\\&/g' |
        tr '\n' ' '
    )" '"$@"'
    
    exec "$JAVACMD" "$@"
}

main "$@"
