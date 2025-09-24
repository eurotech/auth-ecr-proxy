#!/bin/sh
aws ecr get-authorization-token --query 'authorizationData[].authorizationToken' --output text --no-cli-pager > /etc/nginx/aws_token.txt
