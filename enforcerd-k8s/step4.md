### Configure our sample 3 tier application

_TODO Explain the topology of our sample app_

* Deploy network policies that allow traffic from the internet to the UI, UI to frontend, frontend to backend, backend to database. Also, allow the app to communicate with DNS and etcd.

`apoctl api import --namespace ${APOCTL_NAMESPACE}/default --url https://aporeto-inc.github.io/appblock/3tiers-app/aporeto-import.yaml`{{execute}}

* Deploy the sample app itself

`helm install https://aporeto-inc.github.io/appblock/3tiers-app/3tiers-app-1.0.0.tgz --set nodePort=32683`{{execute}}

* Access the app UI

https://[[HOST_SUBDOMAIN]]-32683-[[KATACODA_HOST]].environments.katacoda.com/

* Open the Aporeto console UI and switch to your training namespace. All sample configuration has been created in the default subspace of your session:

> You can view that at the `echo ${APORETO_NAMESPACE}/default`{{execute}} namespace.