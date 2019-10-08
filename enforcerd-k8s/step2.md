_TODO: Explain what we are configuring here_

> To run all commands on this page in a single step, click here: `/opt/aposetup.sh k8s`{{execute}}

### Initialize Helm

* Create tiller account:

`kubectl apply -f /opt/k8s_tiller.yaml`

* Initialize tiller:

`helm init --service-account tiller --upgrade`

* Add Aporeto's helm repository

`helm repo add aporeto https://charts.aporeto.com/releases/${APORETO_RELEASE}/clients`

### Configure Aporeto and Kubernetes

* Create enforcer profile in Aporeto that will ignore loopback traffic, allowing sidecar containers to communicate with each other:

`apoctl api import -f /opt/k8s_enforcer_profile.yaml`

* Create an automation that will allow all traffic at first:

`apoctl api import -f /opt/k8s_allow_all.yaml`

* Create Kubernetes namespaces for Aporeto's tooling:

`kubectl create namespace aporeto-operator && kubectl create namespace aporeto`

### Create application credentials in Aporeto and import them into Kubernetes:

* Enforcer app credential:

`apoctl appcred create enforcerd --type k8s --role "@auth:role=enforcer" | kubectl apply -f - -n aporeto`

* Aporeto Kubernetes operator credential:

`apoctl appcred create aporeto-operator --type k8s --role "@auth:role=aporeto-operator" | kubectl apply -f - -n aporeto-operator`

  - Let's make sure the Kubernetes secrets were created:

`kubectl -n aporeto-operator get secrets && kubectl -n aporeto get secrets`
