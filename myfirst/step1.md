First things first, let's have you log in with your aporeto account. We will automatically create a namespace for you that will have the following format:

`/<your-account>/_training/<session-id>`

Click on the the little arrow right next to the script name to get started:

`/opt/aposetup.sh linux`{{execute}}

### App credentials
are JSON files that contain a negotiated x509 certificate used for authentication as well as more information about the control plane.

> Learn more about [App Credentials](https://junon.console.aporeto.com/docs/main/references/appcredentials/).

We need to create an app credential for
[enforcerd](https://junon.console.aporeto.com/docs/main/concepts/enforcerd-and-processing-units/)

`mkdir -p /var/lib/aporeto && apoctl appcred create enforcerd --role @auth:role=enforcer > /var/lib/aporeto/default.creds`{{execute}}

This creates an app credential and places it in `/var/lib/aporeto/default.creds`, which is the default place enforcerd will look at.