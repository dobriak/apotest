### Deploy the Aporeto Operator

* Install Aporeto's Custom Resource Definitions

`helm install aporeto/aporeto-crds --name aporeto-crds`{{execute}}

* And, finally, the Aporeto Operator for Kubernetes:

`helm install aporeto/aporeto-operator --name aporeto-operator --namespace aporeto-operator`{{execute}}

  - Verify the installation:
`kubectl get pods -n aporeto-operator`{{execute}}

### Install the enforcer

Next command might take a few minutes to complete:
`helm install aporeto/enforcerd --name enforcerd --namespace aporeto`{{execute}}

To check on the progress, issue the following command and look for either `Running` or `Completed` status:

`kubectl get pods --all-namespaces | grep aporeto`{{execute}}

  - Verify the enforcer deployment:

`apoctl api list enforcers --namespace $APOCTL_NAMESPACE -c ID -c name -c namespace -c operationalStatus`{{execute}}
