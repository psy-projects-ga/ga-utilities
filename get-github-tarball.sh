#!/usr/bin/env bash

{ #helpers
	_help() {
		cat <<-EOF

			$(printf "\e[1m%s\e[0m" "Get-github-tarball")

			$(printf "\e[1;4m%s\e[0m" "Usage:")
			  get-github-tarball [--options]

			$(printf "\e[1;4m%s\e[0m" "Options:")
			  -h, --help      <boolean?>      Display this help information.
			  -o, --owner     <string?>       Set Owner value.
			  -r, --repo      <string?>       Set Repo value.
			  -t, --token     <string?>       Set Token value.
			  -O, --output    <string?>       Set Output path directory value.

			$(printf "\e[1;4m%s\e[0m" "Examples:")
			  get-github-tarball -o "psy" -r "bash-library" -t "ghp_123..." -O "./lib"

			  get-github-tarball \ 
			    --owner "psy" \ 
			    --repo "bash-library" \ 
			    --token "ghp_123..." \ 
			    --output "./lib"

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
			-O | --output) path_output_directory="${val:?"Option \"${arg}\" requires an argument."}" && shift ;;
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
	get_github_tarball() {
		{ #helpers
			http_request() {
				if [[ -n "${token}" ]]; then
					curl \
						--header "Accept: application/vnd.github+json" \
						--header "Authorization: Bearer ${token}" \
						--header "X-GitHub-Api-Version: 2022-11-28" \
						--location "${url}" \
						--output "${path_tmp_output_tar_file}" \
						--write-out "%{http_code}" \
						--silent
				else
					curl \
						--header "Accept: application/vnd.github+json" \
						--header "X-GitHub-Api-Version: 2022-11-28" \
						--location "${url}" \
						--output "${path_tmp_output_tar_file}" \
						--write-out "%{http_code}" \
						--silent
				fi
			}
		}

		{ #utilities
			run_request() {
				if ((http_response_code == 200)); then
					tar \
						--extract \
						--gzip \
						--strip-components=1 \
						--directory "${path_output_directory}" \
						--file "${path_tmp_output_tar_file}" ||
						throw_error "Failed to extract tarball from \"${path_tmp_output_tar_file}\" to \"${path_output_directory}\""

					printf "\e[93m%s  \e[96m\"%s\"\n" \
						$'\n'"Info:" "Tarball downloaded and extracted successfully from Github" \
						"Path:" "${path_output_directory}" \
						"Url: " "github.com/${owner}/${repo}"

					printf "\e[0m\n\n"

					if type tree &>/dev/null; then
						tree --dirsfirst "${path_output_directory}"
					else
						ls -hasl --color "${path_output_directory}"
					fi

					du -hs "${path_output_directory}"

					rm -fr "${path_tmp_output_directory}"

					return 0
				else
					printf "\e[91m%s  \e[95m\"%s\"\n" \
						$'\n'"ERROR:" "Failed get Tarball from Github" \
						"Code: " "${http_response_code}" \
						"Url:  " "${url}"

					[[ -s "${path_tmp_output_tar_file}" ]] && cat "${path_tmp_output_tar_file}"

					rm -fr "${path_tmp_output_directory}"

					return 1
				fi
			}
		}

		{ #variables
			declare -i http_response_code="${http_response_code:+0}"

			declare \
				url="${url:+}" \
				path_tmp_output_directory="${path_tmp_output_directory:+}" \
				path_tmp_output_tar_file="${path_tmp_output_tar_file:+}"
		}

		{ #setting-variables

			{ # url
				printf -v "url" "https://%s/%s/%s/%s" \
					"api.github.com/repos" \
					"${owner}" \
					"${repo}" \
					"tarball"
			}

			{ # path_tmp_output_directory
				path_tmp_output_directory="$(mktemp --directory -t "get_github_tarball.XXXXXX")"
			}

			{ # path_tmp_output_tar_file
				path_tmp_output_tar_file="${path_tmp_output_directory}/${repo}.tar.gz"
			}

			{ # http_response_code
				http_response_code="$(http_request)"
			}

			{ # path_output_directory
				path_output_directory="$(normalize_path "${path_output_directory}")"

				[[ -d "${path_output_directory}" ]] || mkdir -p "${path_output_directory}"
			}
		}

		:

		run_request || throw_error "Failed to get tarball from Github"
	}
}

{ #variables
	declare \
		owner="${owner:+}" \
		repo="${repo:+}" \
		token="${token:+}" \
		path_output_directory="${path_output_directory:+}"
}

{ #setting-variables
	config_parse_args "${@}"

	type curl &>/dev/null || throw_error "command \"curl\" is required"

	[[ -n "${owner}" ]] || throw_error "option \"--owner\" is required"
	[[ -n "${repo}" ]] || throw_error "option \"--repo\" is required"
	[[ -n "${path_output_directory}" ]] || throw_error "option \"--output\" is required"
}

:

get_github_tarball
