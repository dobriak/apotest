#!/bin/bash
# aposetup.sh
#  setup - Setup a linux / Mac machine with apoctl and init a temp namespace
#  linux - install enforcer on a linux box
#  k8s   - prepare and install aporeto kubernetes operator
#  dproxy - disable local userland proxy in docker
#
# Overrides: APORETO_RELEASE

APORETO_NS_PREFIX="_training"
APORETO_RELEASE=${APORETO_RELEASE:-"release-3.11.15"}
APORETO_SESSION_ID="$(uuidgen)"
DEFAULT_API_URL="https://api.console.aporeto.com"
DEFAULT_CLAD_URL="https://console.aporeto.com"
DEFAULT_HELM_REPO_URL="https://charts.aporeto.com/clients"

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
  curl -sSL "https://download.aporeto.com/releases/${APORETO_RELEASE}/apoctl/linux/apoctl" -o /usr/local/bin/apoctl
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
  echo "Aporeto account name "
  read -r APORETO_ACCOUNT
  echo "Aporeto account password "
  read -r -s APORETO_PASSWORD
  echo
  echo "Working ..."

  ## auth
  eval "$(apoctl auth aporeto --account "${APORETO_ACCOUNT}" --password "${APORETO_PASSWORD}" --validity 1h -e)"
}

create_namespace () {
  ## create namespace
  session_namespace="/${APORETO_ACCOUNT}/${APORETO_NS_PREFIX}/${APORETO_SESSION_ID}"
  create_ns_if_needed "/${APORETO_ACCOUNT}" "${APORETO_NS_PREFIX}"
  sleep 1
  create_ns_if_needed "/${APORETO_ACCOUNT}/${APORETO_NS_PREFIX}" "${APORETO_SESSION_ID}"

  echo
  echo "Katacoda training namespace is ready:"
  echo
  echo "  ${DEFAULT_CLAD_URL}/?namespace=${session_namespace}"
  echo
}

write_config () {
  ## writing configuration file
  cat << EOF > ~/.aporeto
export APOCTL_API=${DEFAULT_API_URL}
export APOCTL_NAMESPACE=${session_namespace}
export APOCTL_TOKEN=${APOCTL_TOKEN}
export APORETO_ACCOUNT=${APORETO_ACCOUNT}
export APORETO_NAMESPACE=${session_namespace}
export APORETO_RELEASE=${APORETO_RELEASE}
export APORETO_SESSION_ID=${APORETO_SESSION_ID}
export DEFAULT_CLAD_URL=${DEFAULT_CLAD_URL}
export DEFAULT_HELM_REPO_URL=${DEFAULT_HELM_REPO_URL}

alias nslink="echo \"\${DEFAULT_CLAD_URL}/?namespace=\${APOCTL_NAMESPACE}\""
EOF
}

obtain_admin_appcred () {
  if [ -z "${APORETO_ACCOUNT}" ]; then
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

create_tiller () {
  cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF
}

create_enforcer_profile () {
  cat <<'EOF' | apoctl api import -f -
label: kubernetes-default-enforcerprofile
data:
  enforcerprofiles:
  - name: kubernetes-default
    metadata:
    - '@profile:name=kubernetes-default'
    description: Default Profile for Kubernetes
    excludedNetworks:
    - 127.0.0.0/8
    ignoreExpression:
    - - '@app:k8s:namespace=aporeto'
    - - '@app:k8s:namespace=aporeto-operator'
    - - '@app:k8s:namespace=kube-system'
    excludedInterfaces: []
    targetNetworks: []
    targetUDPNetworks: []
  enforcerprofilemappingpolicies:
  - name: fallback-kubernetes-default
    fallback: true
    description: "Kubernetes fallback: if there is no other profile, use the default Kubernetes profile."
    object:
    - - '@profile:name=kubernetes-default'
    subject:
    - - $identity=enforcer
EOF
}

create_automation_all_connections () {
  cat <<'EOF' | apoctl api import -f -
label: install-default-allow-all-policies
data:
  automations:
  - name: install-default-allow-all-policies
    description: Installs default allow all fallback policies for every child namespace that gets created to mimic Kubernetes default behavior.
    trigger: Event
    events:
      namespace:
      - create
    entitlements:
      externalnetwork:
      - create
      networkaccesspolicy:
      - create
    condition: |-
      function when(api, params) {
          return { continue: true, payload: { namespace: params.eventPayload.entity } };
      }
    actions:
    - |-
      function then(api, params, payload) {
          api.Create('externalnetwork', {
              name: 'external-tcp-all',
              description: 'Created by an automation on namespace creation. It is safe to be deleted, if not required.',
              metadata: ['@ext:name=tcpall'],
              entries: ['0.0.0.0/0'],
              ports: ['1:65535'],
              protocols: ['tcp'],
              propagate: true,
          }, payload.namespace.name);
          api.Create('externalnetwork', {
              name: 'external-udp-all',
              description: 'Created by an automation on namespace creation. It is safe to be deleted, if not required.',
              metadata: ['@ext:name=udpall'],
              entries: ['0.0.0.0/0'],
              ports: ['1:65535'],
              protocols: ['udp'],
              propagate: true,
          }, payload.namespace.name);
          api.Create('networkaccesspolicy', {
              name: 'default-fallback-ingress-allow-all',
              description: 'Created by an automation on namespace creation. It is safe to be deleted, if not required.',
              metadata: ['@netpol=default-fallback'],
              propagate: true,
              fallback: true,
              logsEnabled: true,
              observationEnabled: true,
              observedTrafficAction: 'Apply',
              action: 'Allow',
              applyPolicyMode: 'IncomingTraffic',
              subject: [
                  ['$identity=processingunit'],
                  ['@ext:name=tcpall'],
                  ['@ext:name=udpall'],
              ],
              object: [['$namespace='+payload.namespace.name]],
          }, payload.namespace.name);
          api.Create('networkaccesspolicy', {
              name: 'default-fallback-egress-allow-all',
              description: 'Created by an automation on namespace creation. It is safe to be deleted, if not required',
              metadata: ['@netpol=default-fallback'],
              propagate: true,
              fallback: true,
              logsEnabled: true,
              observationEnabled: true,
              observedTrafficAction: 'Apply',
              action: 'Allow',
              applyPolicyMode: 'OutgoingTraffic',
              subject: [['$namespace='+payload.namespace.name]],
              object: [
                  ['$identity=processingunit'],
                  ['@ext:name=tcpall'],
                  ['@ext:name=udpall'],
              ],
          }, payload.namespace.name);
      }
EOF
}

prepare_k8s () {
  if [ ! -f ~/.aporeto ]; then
    echo "Run '"${0}" setup' first"
    exit 1
  fi
  source ~/.aporeto
  echo "> Creating tiller account and initializing helm"
  create_tiller
  helm init --service-account tiller --upgrade --wait

  echo "> Adding Aporeto's helm repository"
  helm repo add aporeto https://charts.aporeto.com/releases/${APORETO_RELEASE}/clients

  echo "> Creating enforcer profile in Aporeto that will ignore loopback traffic, allowing sidecar containers to communicate with each other"
  create_enforcer_profile

  echo "> Create an automation in Aporeto that will allow all traffic at first"
  create_automation_all_connections

  echo "> Creating Kubernetes namespaces and credentials for Aporeto's tooling"
  kubectl create namespace aporeto-operator
  kubectl create namespace aporeto
  apoctl appcred create enforcerd --type k8s --role "@auth:role=enforcer" | kubectl apply -f - -n aporeto
  apoctl appcred create aporeto-operator --type k8s --role "@auth:role=aporeto-operator" | kubectl apply -f - -n aporeto-operator

  echo "> Making sure the credentials are stored in Kubernetes"
  kubectl -n aporeto-operator get secrets | grep Opaque
  kubectl -n aporeto get secrets | grep Opaque

  echo "> Deploying the Aporeto Operator"
  helm install aporeto/aporeto-crds --name aporeto-crds --wait
  helm install aporeto/aporeto-operator --name aporeto-operator --namespace aporeto-operator --wait
  kubectl get pods -n aporeto-operator
  #echo "Waiting for the Aporeto Operator..."
  #sleep 60s
  echo "> Install the enforcer and verify it"
  helm install aporeto/enforcerd --name enforcerd --namespace aporeto --wait
  #echo "Waiting for the enforcer DaemonSet..."
  #sleep 60s
  kubectl get pods --all-namespaces | grep aporeto
  apoctl api list enforcers --namespace ${APOCTL_NAMESPACE} -c ID -c name -c namespace -c operationalStatus
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