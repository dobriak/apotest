### Configure our sample 3 tier application

_TODO Explain the topology of our sample app_

* Deploy network policies that allow traffic from the internet to the UI, UI to frontend, frontend to backend, backend to database. Also, allow the app to communicate with DNS and etcd.

`cat <<'EOF' | apoctl api import --namespace ${APOCTL_NAMESPACE}/default -f -
APIVersion: 1
label: 3tiers-app-network-rules
data:
  networkaccesspolicies:
  - name: Allow App to DNS
    action: "Allow"
    subject:
    - - "app=3tiers-app"
    object:
    - - "ext:role=dns"

    networkaccesspolicies:
  - name: Allow DNS to App (docker-compose-workaround)
    action: "Allow"
    subject:
    - - "ext:role=docker-compose-dns"
    object:
    - - "app=3tiers-app"

  - name: Allow App to etcd
    action: "Allow"
    logsEnabled: true
    subject:
    - - "app=3tiers-app"
    object:
    - - "role=etcd"

  - name: Allow Internet to UI
    action: "Allow"
    logsEnabled: true
    subject:
    - - "ext:role=internet"
    object:
    - - "app=3tiers-app"
      - "role=ui"

  - name: Allow UI to Frontend
    action: "Allow"
    logsEnabled: true
    subject:
    - - "app=3tiers-app"
      - "role=ui"
    object:
    - - "app=3tiers-app"
      - "role=frontend"

  - name: Allow Frontend to Backend
    action: "Allow"
    logsEnabled: true
    subject:
    - - "app=3tiers-app"
      - "role=frontend"
    object:
    - - "app=3tiers-app"
      - "role=backend"

  - name: Allow Backend to Database
    action: "Allow"
    logsEnabled: true
    subject:
    - - "app=3tiers-app"
      - "role=backend"
    object:
    - - "app=3tiers-app"
      - "role=database"

  externalnetworks:
  - name: dns
    entries:
    - 0.0.0.0/0
    ports:
    - "53"
    protocols:
    - udp
    associatedTags:
    - ext:role=dns

  - name: docker-compose-dns
    entries:
    - 127.0.0.0/8
    protocols:
    - udp
    associatedTags:
    - ext:role=docker-compose-dns

  - name: internet
    entries:
    - 0.0.0.0/0
    ports:
    - "1:65000"
    protocols:
    - tcp
    associatedTags:
    - ext:role=internet
EOF`{{execute}}

* Deploy the sample app itself

`helm install https://aporeto-inc.github.io/appblock/3tiers-app/3tiers-app-1.0.0.tgz --set nodePort=32683`{{execute}}

* Access the app UI

https://[[HOST_SUBDOMAIN]]-32683-[[KATACODA_HOST]].environments.katacoda.com/

* Open the Aporeto console UI and switch to your training namespace. All sample configuration has been created in the default subspace of your session:

> You can view that at the `echo ${APORETO_NAMESPACE}/default`{{execute}} namespace.