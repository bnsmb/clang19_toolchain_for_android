#!/usr/bin/env bash

declare -r APP_DIRECTORY="$(realpath "$(( [ -n "${BASH_SOURCE}" ] && dirname "$(realpath "${BASH_SOURCE[0]}")" ) || dirname "$(realpath "${0}")")")"

declare action
declare packages
declare arg
declare args

if [ "${#}" = '0' ]; then
	args+='--help'
fi

while [[ "${#}" -gt '0' ]]; do
	
	if [ "${1}" = 'update' ]; then
		action='--update'
	elif [ "${1}" = 'install' ]; then
		action='--install'
	elif [ "${1}" = 'destroy' ]; then
		action='--destroy'
	elif [ "${1}" = 'remove' ] || [ "${1}" = 'uninstall' ] || [ "${1}" = 'autoremove' ] || [ "${1}" = 'purge' ]; then
		action='--uninstall'
	elif [ "${1}" = 'search' ] || [ "${1}" = 'show' ]; then
		arg+="--${1}='${2}'"
		shift
	elif [[ "${1}" = '-p' || "${1}" = '--prefix' || "${1}" = '--install-prefix' || \
		"${1}" = '-c' || "${1}" = '--concurrency' || "${1}" = '--parallelism' || \
		"${1}" = '--loglevel' ]]; then
		arg+="${1}='${2}'"
		shift
	elif [[ "${1}" == '-'* ]]; then
		args+="${1} "
	else
		if ! [[ "${action}" = '--install' || "${action}" = '--uninstall' ]]; then
			echo "fatal error: This argument is invalid or was not recognized: ${1}" 1>&2
			exit '1'
		fi
		
		packages+="${1};"
	fi
	
	if [ -n "${arg}" ]; then
		args+="${arg} " && arg=''
	fi
	
	shift
done

if [ -n "${packages}" ]; then
	packages="'${packages}'"
fi

eval "${APP_DIRECTORY}/nz" ${args} ${action} ${packages}

exit "${?}"
