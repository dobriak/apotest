#!/bin/bash
APORETO_RELEASE="release-3.11.15"
DEFAULT_CLAD_URL="https://console.aporeto.com"
DEFAULT_API_URL="https://api.console.aporeto.com"
DEFAULT_HELM_REPO_URL="https://charts.aporeto.com/clients"
APORETO_NS_PREFIX="_training"
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
EOF
}

obtain_admin_appcred () {
  if [ -z "$APORETO_ACCOUNT" ]; then
    echo "Please authenticate first."
    exit 1
  fi
  echo "Getting namespace editor app credential"
  [ -d ~/.apoctl ] || mkdir ~/.apoctl
  apoctl appcred create administrator-credentials --role @auth:role=namespace.editor -n "/${APORETO_ACCOUNT}/${APORETO_NS_PREFIX}/${APORETO_SESSION_ID}" > ~/.apoctl/creds.json
  chmod 400 ~/.apoctl/creds.json
  echo "creds: ~/.apoctl/creds.json" > ~/.apoctl/default.yaml
  apoctl auth verify
}

disable_docker_proxy () {
  echo "> Disabling docker's userland proxy"
  jq '. + {"userland-proxy": false}' /etc/docker/daemon.json > /etc/docker/daemon.json.new
  mv /etc/docker/daemon.json.new /etc/docker/daemon.json
  echo "> Restarting docker"
  systemctl restart docker
}

prepare_k8s () {
  if [ ! -f ~/.aporeto ]; then
    echo "Run '/opt/aposetup.sh setup' first"
    exit 1
  fi
  source ~/.aporeto
  echo "> Creating tiller account and initializing helm"
  kubectl apply -f /opt/k8s_tiller.yaml
  helm init --service-account tiller --upgrade

  echo "> Adding Aporeto's helm repository"
  helm repo add aporeto https://charts.aporeto.com/releases/${APORETO_RELEASE}/clients

  echo "> Creating enforcer profile in Aporeto that will ignore loopback traffic, allowing sidecar containers to communicate with each other"
  apoctl api import -f /opt/k8s_enforcer_profile.yaml

  echo "> Create an automation in Aporeto that will allow all traffic at first"
  apoctl api import -f /opt/k8s_allow_all.yaml

  echo "> Creating Kubernetes namespaces and credentials for Aporeto's tooling"
  kubectl create namespace aporeto-operator
  kubectl create namespace aporeto
  apoctl appcred create enforcerd --type k8s --role "@auth:role=enforcer" | kubectl apply -f - -n aporeto
  apoctl appcred create aporeto-operator --type k8s --role "@auth:role=aporeto-operator" | kubectl apply -f - -n aporeto-operator

  echo "> Making sure the credentials are stored in Kubernetes"
  kubectl -n aporeto-operator get secrets | grep Opaque
  kubectl -n aporeto get secrets | grep Opaque

  echo "> Deploy the Aporeto Operator"
  helm install aporeto/aporeto-crds --name aporeto-crds
  helm install aporeto/aporeto-operator --name aporeto-operator --namespace aporeto-operator
  kubectl get pods -n aporeto-operator

  echo "> Install the enforcer and verify it"
  helm install aporeto/enforcerd --name enforcerd --namespace aporeto
  sleep 60s
  kubectl get pods --all-namespaces | grep aporeto
  apoctl api list enforcers --namespace $APOCTL_NAMESPACE -c ID -c name -c namespace -c operationalStatus
}

# Main
cmd=${1?"Usage: $0 setup,linux,k8s,dproxy"}

case "${cmd}" in
  "setup")
    install_apoctl
    authenticate
    create_namespace
    obtain_admin_appcred
    write_config
    ;;
  "linux")
    echo "linux stuff here"
    ;;
  "k8s")
    prepare_k8s
    ;;
  "dproxy")
    disable_docker_proxy
    ;;
  "*")
    echo "Unknown command: ${cmd}"
    exit 1
    ;;
esac