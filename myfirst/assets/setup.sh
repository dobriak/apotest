#!/bin/bash
source /opt/aporeto.conf

APORETO_SESSION_ID="$(uuidgen)"

prompt () {
    local vname; vname="$1"
    local message; message="$2"
    local default; default="$3"

    echo -n "$message$( [ -n "$default" ] && echo " ($default)"): "
    read -r value
    export "$vname=${value:-$default}"
}

prompt_password () {
    local vname; vname="$1"
    local message; message="$2"
    echo -n "$message"
    read -r -s value
    export "$vname=${value}"
}

create_ns_if_needed () {
    local parent; parent="$1"
    local ns; ns="$2"

    if [[ "$(apoctl api count ns -n "$parent" --filter "name == $parent/$ns")" == "0" ]]; then
        apoctl api create ns -n "$parent" -k name "$ns" > /dev/null || exit 1
    fi
}

install_apoctl () {
  # get apoctl
  echo "> Installing apoctl"
  curl -sSL "https://download.aporeto.com/releases/$APORETO_RELEASE/apoctl/linux/apoctl" -o /usr/local/bin/apoctl
  chmod +x /usr/local/bin/apoctl
}

authenticate () {
  ## user input
  echo "Aporeto Katacoda Session Configuration"
  echo
  echo "This script configures the Katacoda environment"
  echo "to make it point to a temporay namespace in"
  echo "your Aporeto account."
  echo
  echo "Please enter your credentials:"
  echo
  prompt APORETO_ACCOUNT "Aporeto account name "
  prompt_password APORETO_PASSWORD "Aporeto account password "

  ## auth
  eval "$(apoctl auth aporeto --account "$APORETO_ACCOUNT" --password "$APORETO_PASSWORD" --validity 1h -e)"
}

create_namespace () {
  ## create namespace
  session_namespace="/$APORETO_ACCOUNT/$APORETO_NS_PREFIX/$APORETO_SESSION_ID"
  create_ns_if_needed "/$APORETO_ACCOUNT" "$APORETO_NS_PREFIX"
  sleep 1
  create_ns_if_needed "/$APORETO_ACCOUNT/$APORETO_NS_PREFIX" "$APORETO_SESSION_ID"

  echo
  echo "Katacoda training namespace is ready:"
  echo
  echo "  $DEFAULT_CLAD_URL/?namespace=$session_namespace"
  echo
}

write_config () {
  ## writing configuration file
  cat << EOF > ~/.aporeto
export APORETO_RELEASE=$APORETO_RELEASE
export DEFAULT_CLAD_URL=$DEFAULT_CLAD_URL
export DEFAULT_HELM_REPO_URL=$DEFAULT_HELM_REPO_URL
export APORETO_SESSION_ID=$APORETO_SESSION_ID
export APORETO_ACCOUNT=$APORETO_ACCOUNT
export APORETO_NAMESPACE=$session_namespace
export APOCTL_NAMESPACE=$session_namespace
export APOCTL_TOKEN=$APOCTL_TOKEN
export APOCTL_API=$DEFAULT_API_URL

alias nslink="echo \"\$DEFAULT_CLAD_URL/?namespace=\$APOCTL_NAMESPACE\""
[ -f /opt/post-setup.sh ] && source /opt/post-setup.sh
EOF
}

disable_docker_proxy () {
  jq '. + {"userland-proxy": false}' /etc/docker/daemon.json > /etc/docker/daemon.json.new
  mv /etc/docker/daemon.json.new /etc/docker/daemon.json
  systemctl restart docker
}

# Main
cmd=${1?"Usage: $0 setup,linux,k8s"}

case "${cmd}" in
  "setup")
    install_apoctl
    disable_docker_proxy
    ;;
  "linux")
    authenticate
    create_namespace
    write_config
    ;;
  "k8s")
    echo "K8s content coming very soon, stay tuned!"
    exit 0
    ;;
  "*")
    echo "Unknown command: ${cmd}"
    exit 1
    ;;
esac