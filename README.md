# Auth-ECR-Proxy

### Description
This proxy for AWS ECR registry contains an upper layer for the authentication based on username password and url requested.
The base image is openresty centos, the authentication layer is made with LUA language on nginx, it is required a database mysql, then there is the proxy that use the IAM role or AWS credentials for renew every 6 hours by default the authentication token for access the ECR registry.

In this repository you can find also the script for create the db tables required for the authentication.
You can manage the users, groups and uris associated to the groups.

The default uri for having a successfull login it's /v2/.

You can enable the pull of the images by adding the uri in this format:
/v2/registry/image/manifests/tag


Variables:
```
AWS_KEY     - optional
AWS_SECRET  - optional
REGION      - optional
RENEW_TOKEN - optional default 6h
REGISTRY_ID - optional, used for cross account access
DBHOST      - required
DBPORT      - required
DBNAME      - required
DBUSER      - required
DBPASSWORD  - required
```

[Docker Image](https://hub.docker.com/r/eurotech/auth-ecr-proxy)
