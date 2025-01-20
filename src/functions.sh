# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck source=summary.sh
. "${SCRIPT_DIR=}summary.sh"
# shellcheck source=validation.sh
. "${SCRIPT_DIR=}validation.sh"

# Function that determine if FULL scan is requested
# INPUT_TRIGGERING_EVENT is required
# $? - return value - 0 on success
is_full_scan_demanded () {
  case "${INPUT_TRIGGERING_EVENT-${GITHUB_EVENT_NAME}}" in
    "merge_group")
      return 1
      ;;

    "push")
      return 0
      ;;

    "pull_request")
      return 1
      ;;

    "manual")
      is_false "${INPUT_DIFF_SCAN}" && return 0
      ;;

    *)
      # Perform Differential scans by default
  esac

  return 1
}

# Function that determine if strict check on push events is requested
# INPUT_TRIGGERING_EVENT is required
# $? - return value - 0 on success
is_strict_check_on_push_demanded () {
  [[ "${INPUT_TRIGGERING_EVENT-${GITHUB_EVENT_NAME}}" = "push" ]] || return 1
  is_false "${INPUT_STRICT_CHECK_ON_PUSH:-"false"}" && return 2
  return 0
}

# Function that picks values of BASE and HEAD commit based on triggrring event (INPUT_TRIGGERING_EVENT)
# It sets BASE and HEAD for external use.
# $? - return value - 0 on success
pick_base_and_head_hash () {
  case ${INPUT_TRIGGERING_EVENT-${GITHUB_EVENT_NAME}} in
    "merge_group")
      export BASE=${INPUT_MERGE_GROUP_BASE:-}
      export HEAD=${INPUT_MERGE_GROUP_HEAD:-}
      is_unit_tests && echo "BASE:\"${BASE}\" ; HEAD:\"${HEAD}\""
      ;;

    "push")
      export BASE=${INPUT_PUSH_EVENT_BASE:-}
      export HEAD=${INPUT_PUSH_EVENT_HEAD:-}
      is_unit_tests && echo "BASE:\"${BASE}\" ; HEAD:\"${HEAD}\""
      ;;

    "pull_request")
      export BASE=${INPUT_PULL_REQUEST_BASE:-}
      export HEAD=${INPUT_PULL_REQUEST_HEAD:-}
      is_unit_tests && echo "BASE:\"${BASE}\" ; HEAD:\"${HEAD}\""
      ;;

    "manual")
      export BASE=${INPUT_BASE:-}
      export HEAD=${INPUT_HEAD:-}
      is_unit_tests && echo "BASE:\"${BASE}\" ; HEAD:\"${HEAD}\""
    ;;

    *)
      echo -e "❓ ${RED}Value of required variable INPUT_TRIGGERING_EVENT isn't set or contains unsupported value. Supported values are: (merge_group | pull_request | push | manual).${NOCOLOR}"
      return 1
  esac

  if [[ -z ${BASE} ]] || [[ -z ${HEAD} ]]; then
    echo -e "❓ ${RED}Value of required variables BASE and/or HEAD isn't set or contains unsupported value.${NOCOLOR}"
    return 2
  fi
}

# Function that returns an array of paths to scripts eligible for scanning
# https://stackoverflow.com/a/12985353/10221282
# $1 - <string> absolute path to a file with list of files
# $2 - <string> name of a variable where the result array will be stored
# $3 - <0|1> is full scan - 0 ~ true, 1 ~ false
get_scripts_for_scanning () {
  [[ $# -le 2 ]] && return 1
  local output=$2
  local full_scan=$3

  # Find modified shell scripts
  local list_of_changes=()
  [[ ${full_scan} -eq 0 ]] && file_to_array "${1}" "list_of_changes"
  [[ ${full_scan} -eq 1 ]] && tab_separated_file_to_array "${1}" "list_of_changes"

  # Create a list of scripts for testing
  local scripts_for_scanning=()
  for line in "${list_of_changes[@]}"; do
    local file
    local scanning_path
    [[ ${full_scan} -eq 0 ]] && file="${line}" && scanning_path="./${file}"
    # When diff scan is performed, we wan't to keep information about the original file path in case of renaming
    [[ ${full_scan} -eq 1 ]] && file=$(cut -f2 <<< "${line}") && scanning_path="./$(cut -f1 <<< "${line}")${TAB}./${file}"

    is_symlink "${file}" && continue
    is_directory "${file}" && continue
    is_matched_by_path "${file}" "${INPUT_EXCLUDE_PATH-}" && continue
    is_matched_by_path "${file}" "${INPUT_INCLUDE_PATH-}" && scripts_for_scanning+=("${scanning_path}") && continue
    is_shell_extension "${file}" && scripts_for_scanning+=("${scanning_path}") && continue
    has_shebang "${file}" && scripts_for_scanning+=("${scanning_path}")
  done

  eval "${output}"=\("${scripts_for_scanning[*]@Q}"\)
  is_unit_tests && eval echo "\${${output}[@]@Q}"
}

# Function to check whether the given file has the .{,a,ba,da,k}sh and .bats extension
# https://stackoverflow.com/a/6926061
# $1 - <string> absolute path to a file
# $? - return value - 0 on success
is_shell_extension () {
  [[ $# -le 0 ]] && return 1
  local file="$1"

  case ${file} in
    *.sh) return 0;;
    *.ash) return 0;;
    *.bash) return 0;;
    *.dash) return 0;;
    *.ksh) return 0;;
    *.bats) return 0;;
    *) return 2
  esac
}

# Function to check whether the given file contains a shell shebang
# - supported interpreters are {,a,ba,da,k}sh and bats including shellcheck directive
# - also supports emacs and vi/vim file types specifications
# https://unix.stackexchange.com/a/406939
# emacs: https://www.gnu.org/software/emacs/manual/html_node/emacs/Choosing-Modes.html
# vi/vim: http://vimdoc.sourceforge.net/htmldoc/options.html#modeline
# $1 - <string> absolute path to a file
# $? - return value - 0 on success
has_shebang () {
  [[ $# -le 0 ]] && return 1
  local file="$1"

  # shell shebangs detection
  if head -n1 "${file}" | grep --quiet -E '^\s*((#|!)|(#\s*!)|(!\s*#))\s*(/usr(/local)?)?/bin/(env\s+)?(sh|ash|bash|dash|ksh|bats)\b'; then
    return 0
  fi

  # ShellCheck shell directive detection
  if grep --quiet -E '^\s*#\s*shellcheck\s+shell=(sh|ash|bash|dash|ksh|bats)\s*' "${file}"; then
    return 0
  fi

  # Emacs mode detection
  if grep --quiet -E '^\s*#.*\s+-\*-\s+(mode:\s+)?(sh|ash|bash|dash|ksh|bats|shell(-| )script)\s+-\*-\s*' "${file}"; then
    return 0
  fi

  # Vi and Vim modeline filetype detection
  if grep --quiet -E '^\s*#\s+vim?:\s+(set\s+)?(ft|filetype)=(sh|ash|bash|dash|ksh|bats)\s*' "${file}"; then
    return 0
  fi

  return 2
}

# Function to test if given file is symbolic link
# $1 - <string> path to a file
# $? - return value - 0 on success
is_symlink () {
  [[ $# -le 0 ]] && return 1
  local file="$1"

  [[ -L "${file}" ]] && return 0

  return 2
}

# Function to test if given file path is directory
# $1 - <string> file path
# $? - return value - 0 on success
is_directory () {
  [[ $# -le 0 ]] && return 1
  local file="$1"

  [[ -d "${file}" ]] && return 0

  return 2
}

# Function to test if given file path is listed in the privided input list
# https://unix.stackexchange.com/a/165981/509101
# $1 - <string> file path
# $2 - <string> input list of files
# $? - return value - 0 on success
is_matched_by_path () {
  [[ $# -le 1 ]] && return 1
  local file="$1"

  # When multiple paths are provided they might be separated by space and/or newline, lets replace all newlines with spaces in order to avoid issues with glob pattern matching in eval
  # /action/functions.sh: line 215: tests/**: No such file or directory
  local file_paths=""
  file_paths=$(tr '\r\n' ' ' <<< "$2")

  set -f
  globs=$(eval "echo ${file_paths}")

  for pattern in ${globs}; do
    # shellcheck disable=SC2053
    # We want to use glob pattern matching here
    [[ ${file} == ${pattern} ]] && { set +f; return 0; }
  done

  set +f

  return 2
}

# Function that reads a file of paths and stores them in an array
# https://stackoverflow.com/a/28109890/10221282
# $1 - file path
# $2 - name of a variable where the result array will be stored
# $? - return value - 0 on success
file_to_array () {
  [[ $# -le 1 ]] && return 1
  local output=()

  while IFS= read -r -d '' file; do
    is_file_inside_scan_directory "${file}" || continue
    output+=("${file}")
  done < "${1}"

  is_unit_tests && echo "${output[@]}"

  eval "${2}"=\("${output[*]@Q}"\)
}

# Function that reads a file and stores them in an array
# file is expected to have format of: <type><tab><path><?tab><?path>
# https://stackoverflow.com/a/28109890/10221282
# $1 - file path
# $2 - name of a variable where the result array will be stored
# $? - return value - 0 on success
tab_separated_file_to_array () {
  [[ $# -le 1 ]] && return 1
  local output=()

  # https://stackoverflow.com/a/12916758/10221282
  while IFS=$'\t' read -r -a data || [[ -n "${data[*]}" ]]; do
    base_path="${data[1]}"
    head_path=""

    case "${data[0]}" in
      R)
        echo "::debug::Renamed file detected: ${data[*]}"
        head_path="${data[2]}"
        ;;

      *)
        head_path="${data[1]}"
        ;;
    esac

    is_file_inside_scan_directory "${head_path}" || continue

    output+=("${base_path}${TAB}${head_path}")
  done < "${1}"

  is_unit_tests && echo "${output[@]}"

  eval "${2}"=\("${output[*]@Q}"\)
}

# Function to split array by tabulator into two separate arrays
# $1 - <string> name of a variable where the first array will be stored
# $2 - <string> name of a variable where the second array will be stored
# $@ - <array> array to split
split_array_by_tab () {
  [[ $# -le 2 ]] && return 1

  local paths=("${@:3}")
  local base_paths=()
  local head_paths=()

  for item in "${paths[@]}"; do
    IFS=$'\t' read -r -a paths <<< "${item}"
    base_paths+=("${paths[0]}")
    head_paths+=("${paths[1]}")
  done

  is_unit_tests && echo "${base_paths[@]}" && echo "${head_paths[@]}"

  eval "${1}"=\("${base_paths[*]@Q}"\)
  eval "${2}"=\("${head_paths[*]@Q}"\)
}


# Function to get values for csdiff --file-rename option
# $1 - <number> size of the array
# $2 - <array> array containing values from BASE scan
# $3 - <array> array containing values from HEAD scan
get_csdiff_file_rename () {
  local size=${1}
  shift
  local base=("${@:1:${size}}")
  shift "${size}"
  local head=("${@}")

  local rename_files=()
  for i in "${!base[@]}"; do
    [[ "${base[i]}" == "${head[i]}" ]] && continue
    rename_files+=("--file-rename ${changed_scripts_base[i]},${changed_scripts_head[i]}")
  done

  echo "${rename_files[@]}"
}

# Function to test if given file is inside the scan directory
# $1 - <string> file path
# $? - return value - 0 on success
is_file_inside_scan_directory () {
  [[ $# -le 0 ]] && return 1
  [[ -z "${INPUT_SCAN_DIRECTORY}" ]] && return 0

  is_matched_by_path "${file}" "${INPUT_SCAN_DIRECTORY}"
  return $?
}

# Evaluate if variable contains true value
# https://github.com/fedora-sysv/initscripts/blob/main/etc/rc.d/init.d/functions#L634-L642
# $1 - variable possibly containing boolean value
# $? - return value - 0 on success
is_true() {
    [[ $# -le 0 ]] && return 1

    case "$1" in
      [tT] | [yY] | [yY][eE][sS] | [oO][nN] | [tT][rR][uU][eE] | 1)
        return 0
        ;;

      *)
        return 1
        ;;
    esac
}

# Evaluate if variable contains false value
# https://github.com/fedora-sysv/initscripts/blob/main/etc/rc.d/init.d/functions#L644-L652
# $1 - variable possibly containing boolean value
# $? - return value - 0 on success
is_false() {
    [[ $# -le 0 ]] && return 1

    case "$1" in
      [fF] | [nN] | [nN][oO] | [oO][fF][fF] | [fF][aA][lL][sS][eE] | 0)
        return 0
        ;;

      *)
        return 1
        ;;
    esac
}

# Function to execute shellcheck command with all relevant options
execute_shellcheck () {
  is_true "${INPUT_EXTERNAL_SOURCES}" && local external_sources=--external-sources

  local shellcheck_args=(
    --format=json1
    "${external_sources:-}"
    --severity="${INPUT_SEVERITY}"
    "${@}"
  )

  local output
  output=$(shellcheck "${shellcheck_args[@]}" 2> /dev/null)

  echo "${output}"
}

# Function to check if the action is run in a Debug mode
is_debug () {
  local result
  result=$(is_true "${RUNNER_DEBUG:-0}")

  # shellcheck disable=SC2086
  # return require numeric value
  return ${result}
}

# Function to check if the script is run in GitHub Actions environment
# GITHUB_ACTIONS is set when Differential ShellCheck is running in GitHub Actions
# https://docs.github.com/en/actions/learn-github-actions/variables#default-environment-variables
is_github_actions () {
  [[ -z "${GITHUB_ACTIONS}" ]] && return 1
  return 0
}

# Function to check if the script is run in unit tests environment
is_unit_tests () {
  [[ -z "${UNIT_TESTS}" ]] && return 1
  return 0
}

# Function to generate SARIF report
# $1 - <string> path to a file containing defects detected by scan
# $2 - <string> name of resulting SARIF file
generate_SARIF () {
  [[ $# -le 1 ]] && return 1
  local defects=$1
  local output=$2

  shellcheck_version=$(get_shellcheck_version)

  # GitHub requires an absolute path, so let's remove the './' prefix from it.
  csgrep \
    --strip-path-prefix './' \
    --embed-context 4 \
    --mode=sarif \
    --set-scan-prop='tool:ShellCheck' \
    --set-scan-prop="tool-version:${shellcheck_version}" \
    --set-scan-prop='tool-url:https://www.shellcheck.net/wiki/' \
    "${defects}" > full.sarif

  # Make the SARIF report compact to allow for more efficient uploading to GitHub
  # It also allows to upload more defects in a single request (GitHub limit is 10MB)
  jq --compact-output < full.sarif > "${output}"
}

# Function to upload the SARIF report to GitHub
# Source: https://github.com/github/codeql-action/blob/dbe6f211e66b3aa5e9a5c4731145ed310ed54e28/lib/upload-lib.js#L104-L106
# Parameters: https://github.com/github/codeql-action/blob/69e09909dc219ed3374913e41c167490fc57202a/lib/upload-lib.js#L211-L224
# Values: https://github.com/github/codeql-action/blob/main/lib/upload-lib.test.js#L72
uploadSARIF () {
  is_debug && local verbose=--verbose

  echo '{"commit_oid":"'"${HEAD}"'","ref":"'"${GITHUB_REF//merge/head}"'","analysis_key":"differential-shellcheck","sarif":"'"$(gzip -c output.sarif | base64 -w0)"'","tool_names":["differential-shellcheck"]}' > payload.json

  local curl_args=(
    "${verbose:---silent}"
    -X PUT
    -f "https://api.github.com/repos/${GITHUB_REPOSITORY}/code-scanning/analysis"
    -H "Authorization: token ${INPUT_TOKEN}"
    -H "Accept: application/vnd.github.v3+json"
    -d "@payload.json"
  )

  if curl "${curl_args[@]}" &> curl_std; then
    echo -e "✅ ${GREEN}SARIF report was successfully uploaded to GitHub${NOCOLOR}"
    is_debug && cat curl_std
  else
    echo -e "❌ ${RED}Failed to upload the SARIF report to GitHub${NOCOLOR}"
    cat curl_std
  fi
}

get_shellcheck_version () {
  local shellcheck_version
  shellcheck_version=$(shellcheck --version | grep -w "version:" | cut -s -d ' ' -f 2)

  echo "${shellcheck_version}"
}

# Function that shows versions of currently used commands
show_versions() {
  local shellcheck
  local csutils

  shellcheck=$(get_shellcheck_version)
  csutils=$(csdiff --version)

  echo -e "\
ShellCheck: ${shellcheck}
csutils: ${csutils}"
}

# Logging aliases, use echo -e to use them
export VERSIONS_HEADING="\
\n\n:::::::::::::::::::::\n\
::: ${WHITE}Used Versions${NOCOLOR} :::\n\
:::::::::::::::::::::\n"

export MAIN_HEADING="\
\n\n:::::::::::::::::::::::::::::::\n\
::: ${WHITE}Differential ShellCheck${NOCOLOR} :::\n\
:::::::::::::::::::::::::::::::\n"

# Color aliases, use echo -e to use them
export NOCOLOR='\033[0m'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export ORANGE='\033[0;33m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export WHITE='\033[1;37m'

export TAB=$'\t'
