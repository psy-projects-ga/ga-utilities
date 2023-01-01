#!/usr/bin/env bash

{ #helpers
	_help() {
		cat <<-EOF

			$(printf "\e[1m%s\e[0m" "Get-github-file")

			$(printf "\e[1;4m%s\e[0m" "Usage:")
			  get-github-file [--options]

			$(printf "\e[1;4m%s\e[0m" "Options:")
			  -h, --help      <boolean?>      Display this help information.
			  -o, --owner     <string?>       Set Owner value.
			  -r, --repo      <string?>       Set Repo value.
			  -t, --token     <string?>       Set Token value.
			  -f, --file      <string?>       Set Github path File value.
			  -O, --output    <string?>       Set Output path file value.

			$(printf "\e[1;4m%s\e[0m" "Examples:")
			  get-github-file -o "psy" -r "bash-library" -t "ghp_123..." -f "CHANGELOG.md" -O "./changelog_output.md"

			  get-github-file \ 
			    --owner "psy" \ 
			    --repo "bash-library" \ 
			    --token "ghp_123..." \ 
			    --file "CHANGELOG.md" \ 
			    --output "./changelog_output.md"

		EOF

		exit 0
	}

	config_parse_args() {
		((${#})) || _help

		while ((${#})); do
			arg="${1:-}" val="${2:-}" && shift

			case "${arg}" in
			-h | --help) _help ;;
			-o | --owner) owner="${val:?"Option \"${arg}\" requires an argument."}" && shift ;;
			-r | --repo) repo="${val:?"Option \"${arg}\" requires an argument."}" && shift ;;
			-t | --token) token="${val:?"Option \"${arg}\" requires an argument."}" && shift ;;
			-f | --file) path_remote_file="${val:?"Option \"${arg}\" requires an argument."}" && shift ;;
			-O | --output) path_output_file="${val:?"Option \"${arg}\" requires an argument."}" && shift ;;
			*) throw_error "Unknown option \"${arg}\"" ;;
			esac
		done
	}

	throw_error() {
		printf "\n\n\e[2;31m❌ ERROR: %s\e[0m\n\n\n" "${1:-}"
		exit "${2:-1}"
	}

	normalize_path() {
		declare \
			np__arg_path="${1}" \
			np__path_output="${np__path_output:+}"

		np__normalize_path() {
			[[ "${np__arg_path:0:9}" == "../../../" ]] && {
				: "${PWD%/*}"
				: "${_%/*}"
				np__path_output="${_%/*}/${np__arg_path:9}"
				return
			}

			[[ "${np__arg_path:0:6}" == "../../" ]] && {
				: "${PWD%/*}"
				np__path_output="${_%/*}/${np__arg_path:6}"
				return
			}

			[[ "${np__arg_path:0:3}" == "../" ]] && {
				np__path_output="${PWD%/*}/${np__arg_path:3}"
				return
			}

			[[ "${np__arg_path:0:1}" == "~" ]] && np__path_output="${np__arg_path/\~/${HOME}}" && return

			[[ "${np__arg_path}" =~ ^\.[^/] ]] && np__path_output="${PWD}/${np__arg_path}" && return

			[[ "${np__arg_path:0:1}" == "." ]] && np__path_output="${np__arg_path/\./${PWD}}" && return

			[[ "${np__arg_path:0:1}" != "/" ]] && np__path_output="${PWD}/${np__arg_path}" && return

			[[ "${np__arg_path:0:1}" == "/" ]] && np__path_output="${np__arg_path}" && return
		}

		np__normalize_path

		printf "%s\n" "${np__path_output}"
	}
}

{ #utilities
	get_github_file() {
		{ #helpers
			http_request() {
				if [[ -n "${token}" ]]; then
					curl \
						--header "Accept: application/vnd.github.raw" \
						--header "Authorization: Bearer ${token}" \
						--header "X-GitHub-Api-Version: 2022-11-28" \
						--location "${url}" \
						--output "${path_tmp_output_file}" \
						--write-out "%{http_code}" \
						--silent
				else
					curl \
						--header "Accept: application/vnd.github.raw" \
						--header "X-GitHub-Api-Version: 2022-11-28" \
						--location "${url}" \
						--output "${path_tmp_output_file}" \
						--write-out "%{http_code}" \
						--silent
				fi
			}
		}

		{ #utilities
			run_request() {
				if ((http_response_code == 200)); then
					if [[ -n "${path_output_file}" ]]; then
						mv -f "${path_tmp_output_file}" "${path_output_file}"

						printf "\e[93m%s  \e[96m\"%s\"\n" \
							$'\n'"Info:" "File downloaded successfully from Github" \
							"Path:" "${path_output_file}" \
							"Url: " "github.com/${owner}/${repo}/${path_remote_file}"
					else
						cat "${path_tmp_output_file}"

						[[ -f "${path_tmp_output_file}" ]] && rm -f "${path_tmp_output_file}"
					fi

					return 0
				else
					printf "\e[91m%s  \e[95m\"%s\"\n" \
						$'\n'"ERROR:" "Failed to download file from Github" \
						"Code: " "${http_response_code}" \
						"Url:  " "${url}"

					[[ -s "${path_tmp_output_file}" ]] && cat "${path_tmp_output_file}"

					[[ -f "${path_tmp_output_file}" ]] && rm -f "${path_tmp_output_file}"

					return 1
				fi
			}
		}

		{ #variables
			declare -i http_response_code="${http_response_code:+0}"

			declare \
				url="${url:+}" \
				path_tmp_output_file="${path_tmp_output_file:+}"
		}

		{ #setting-variables

			{ # url
				printf -v "url" "https://%s/%s/%s/%s/%s" \
					"api.github.com/repos" \
					"${owner}" \
					"${repo}" \
					"contents" \
					"${path_remote_file}"
			}

			{ # path_tmp_output_file
				path_tmp_output_file="$(mktemp -t "get_github_file.XXXXXX")"
			}

			{ # http_response_code
				http_response_code="$(http_request)"
			}

			{ # path_output_file
				[[ -n "${path_output_file}" ]] &&
					path_output_file="$(normalize_path "${path_output_file}")"
			}
		}

		:

		run_request || throw_error "Failed to download file from Github"
	}
}

{ #variables
	declare \
		owner="${owner:+}" \
		repo="${repo:+}" \
		token="${token:+}" \
		path_remote_file="${path_remote_file:+}" \
		path_output_file="${path_output_file:+}"
}

{ #setting-variables
	config_parse_args "${@}"

	type curl &>/dev/null || throw_error "command \"curl\" is required"

	[[ -n "${owner}" ]] || throw_error "option \"--owner\" is required"
	[[ -n "${repo}" ]] || throw_error "option \"--repo\" is required"
	[[ -n "${path_remote_file}" ]] || throw_error "option \"--file\" is required"
}

:

get_github_file
