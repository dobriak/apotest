Let's now install enforcerd.

We need to add add Aporeto's GPG key to verify the package signature:

`curl -sSL http://download.aporeto.com/aporeto-packages.gpg | apt-key add -`{{execute}}

We also need to add Aporeto Packages Repository to our apt sources:

`echo "deb https://repo.aporeto.com/ubuntu/$(lsb_release -cs) aporeto main" > /etc/apt/sources.list.d/aporeto.list`{{execute}}

And, finally, let's install and start enforcerd:

`apt update && apt -y install enforcerd
systemctl start enforcerd`{{execute}}

You can check enforcerd is running with the following command:

`systemctl status enforcerd`{{execute}}