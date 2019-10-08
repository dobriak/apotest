_TODO: Explain what we are configuring here_


### Initialize Helm

* Create tiller account:

`kubectl apply -f /opt/k8s_tiller.yaml`{{execute}}

* Initialize tiller:

`helm init --service-account tiller --upgrade`{{execute}}

* Add Aporeto's helm repository

`helm repo add aporeto https://charts.aporeto.com/releases/${APORETO_RELEASE}/clients`{{execute}}

### Configure Aporeto and Kubernetes

* Create enforcer profile in Aporeto that will ignore loopback traffic, allowing sidecar containers to communicate with each other:

`apoctl api import -f /opt/k8s_enforcer_profile.yaml`{{execute}}

* Create an automation that will allow all traffic at first:

`apoctl api import -f /opt/k8s_allow_all.yaml`{{execute}}

* Create Kubernetes namespaces for Aporeto's tooling:

`kubectl create namespace aporeto-operator && kubectl create namespace aporeto`{{execute}}

* Create application credentials in Aporeto and import them into Kubernetes:

  - Enforcer app credential:

`apoctl appcred create enforcerd --type k8s --role "@auth:role=enforcer" | kubectlapply -f - -n aporeto`{{execute}}

  - Aporeto Kubernetes operator credential:

`apoctl appcred create aporeto-operator --type k8s --role "@auth:role=aporeto-operator" | kubectl apply -f - -n aporeto-operator`{{execute}}

* Let's make sure the Kubernetes secrets were created:

`kubectl -n aporeto-operator get secrets && kubectl -n aporeto get secrets`{{execute}}
