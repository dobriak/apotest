To test this installation, we will:

* create a network policy
* start some containers on the linux host
* verify connectivity between them by issuing a curl from one to the others

Let's start with creating a Network Access Policy in Aporeto:

`apoctl api create netpol \
  -k name allow-centos-to-nginx \
  -k subject '[["$name=centos"]]' \
  -k object '[["$name=nginx"]]' \
  -k action Allow`{{execute}}

The network policy describes an allowed connectivity between 2 [processing units](https://docs.aporeto.com/docs/main/concepts/enforcerd-and-processing-units/) named `centos` and `nginx`. In our case they are going to be 2 docker containers running on our host:

* nginx
`docker run -d --rm --name nginx nginx`{{execute}}

* centos
`docker run -it -d --rm --name centos centos`{{execute}}

* other
`docker run -d --rm --name other nginx`{{execute}}

For the verification part of this exercise, we will attempt to connect from the `centos` to the `nginx` processing unit.
We will do that by attaching to `centos` and issuing a curl command pointed to the IP Address under which `nginx` is running.

If our policy is in effect, we should be able to establish that connection:

`docker exec -it centos curl "$(docker inspect nginx | jq -r '.[0].NetworkSettings.Networks.bridge.IPAddress')"`{{execute}}

And to prove that other processing units are not going to be accessible, we will try to perform the same operation, but point to `other` for which we do not have a policy. You should not be allowed to establish a connection in this case:

`docker exec -it centos curl "$(docker inspect other | jq -r '.[0].NetworkSettings.Networks.bridge.IPAddress')"`{{execute}}


You can check now check in your training namespace in [Aporeto's UI](https://console.aporeto.com)  that the communication has been reported and allowed.

> Reminder: you can view your namespace's name by issuing the `nslink`{{execute}} command.