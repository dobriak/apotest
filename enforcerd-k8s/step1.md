_TODO: Explain namespaces_

[//]: # (Let's begin by disabling the userland proxy employed by Docker, as it will interfere with our operations. Execute the following script on the worker node:)
[//]: # (`/opt/aposetup.sh dproxy`{{execute HOST2}})

Let's have you log in with your Aporeto account. We will automatically create a namespace for you in Aporeto that will have the following format:

`/<your-account>/_training/<session-id>`

Click on the the little arrow right next to the script name to get started:

`/opt/aposetup.sh setup && source .aporeto`{{execute}}
