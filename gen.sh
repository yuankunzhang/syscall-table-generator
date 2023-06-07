#!/usr/bin/env bash
set -e
shopt -s globstar

usage() {
  err="${1}"

  if [[ ! -z "${err}" ]]; then
    echo "Error: ${err}"
    echo
  fi

  echo "Usage: ${0} linux-src arch"
  exit 1
}

if [[ "${#}" -ne 2 ]]; then
  usage
fi

linux_src=`echo "${1}" | sed 's/\/*$//g'`             # trim ending slashes
if [[ ! -d "${linux_src}" ]]; then
    usage "invalid Linux source path"
fi

arch="${2}"
if [[ "${arch}" -ne 32 && "${arch}" -ne 64 ]]; then
    usage "arch can only be 32 or 64"
fi

syscall_tbl="$linux_src/arch/x86/entry/syscalls/syscall_${arch}.tbl"
all_defs="/tmp/syscall_defs"

find_all_defs() {
    grep -Poz "(?s)\bSYSCALL_DEFINE[0-6]\(.*?\)" \
        "${linux_src}"/**/*.c |                         # grep SYSCALL_DEFINEs from all C files
        tr -d '\n' |                                    # remove newlines in case the definition spans multiple lines.
        tr '\0' '\n' > "${all_defs}"
}

syscall_def() {
    name="${1}"

    if [[ "${arch}" -eq 32 ]]; then
        exclude_arch=64
    else
        exclude_arch=32
    fi

    grep -P "\(\b${name}\b" "$all_defs" |               # find all occurrances of the name
        grep -v "arch/[^x]" |                           # exclude the wrong archs
        grep -v "arch/x86/um" |                         # exclude "um" (userspace emulation)
        grep -v "_${exclude_arch}.c:" |                 # 32 or 64, that is the question
        head -1                                         # keep only one record, wish me luck
}

print_syscall() {
    source="${1}"
    number="${2}"
    name="${3}"
    entry="${4}"
    args="${5}"

    local arg0 arg1 arg2 arg3 arg4 arg5
    IFS=, read -r arg0 arg1 arg2 arg3 arg4 arg5 <<< "${args}"

    if [[ "${entry}" != "unimplemented" && "${entry}" != "notfound" ]]; then
      name="[${name}](https://man7.org/linux/man-pages/man2/${name}.2.html)"
      source="[${source}](https://github.com/torvalds/linux/tree/master/${source})"
    fi
    echo "|${number}|${name}|${entry}|${source}|${arg0}|${arg1}|${arg2}|${arg3}|${arg4}|${arg5}|"
}

parse_args() {
    def="${1}"

    echo "${def}" |
        sed 's/^[^,)]*[,)]\s*//g; s/)$//g; s/\s\s*/ /g' |   # remove prefix and suffix, and squize spaces
        awk '
BEGIN {
      FS=","
}
{
    for (i = 1; i <= NF; i += 2)
        printf "%s%s%s", $i, $(i + 1), (i + 1 < NF ? "," : "\n")
}'
}

parse_def() {
    line="${1}"

    local number arch name entry compat_entry
    local definition source args
    read -r number arch name entry compat_entry <<< "${line}"

    if [[ -z "${entry// }" ]]; then
        entry="unimplemented"
    else
        def=`syscall_def "${name}"`                     # search by name first

        if [[ -z "${def}" ]]; then                      # then by entry point, without the "sys_" prefix
            def=`syscall_def "${entry#sys_}"`
        fi

        if [[ -z "${def}" ]]; then                      # it's just a bad day
            entry="notfound"
        else
            source=`echo "$def" | cut -d: -f 1`
            source=${source#"${linux_src}/"}
            args=`parse_args "${def}"`
        fi
    fi

    print_syscall "${source}" "${number}" "${name}" "${entry}" "${args}"
}

parse_syscall_table() {
    print_header

    while read line; do
        [[ "${line}" =~ ^[0-9].*$ ]] || continue;
        parse_def "${line}"
    done < $syscall_tbl
}

print_header() {
    if [[ "${arch}" -eq 32 ]]; then
        echo "| %eax | name | entry point | implementation | %ebx | %ecx | %edx | %esi | %edi | %ebp |"
    else
        echo "| %rax | name | entry point | implementation | %rdi | %rsi | %rdx | %r10 | %r8  | %r9  |"
    fi
        echo "|------|------|-------------|----------------|------|------|------|------|------|------|"
}

find_all_defs
parse_syscall_table
