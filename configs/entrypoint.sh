#!/bin/sh

nx_conf=/etc/nginx/conf.d/default.conf
auth_conf=/etc/nginx/authenticate.lua

AWS_IAM='http://169.254.169.254/latest/dynamic/instance-identity/document'
AWS_FOLDER='/root/.aws'

header_config() {
    mkdir -p ${AWS_FOLDER}
    echo "[default]" > /root/.aws/config
}
region_config() {
    echo  "region = $@" >> /root/.aws/config
}

test_iam() {
    curl -q -L ${AWS_IAM} 2>/dev/null | grep -q 'region'
}

test_config() {
    grep -qrni $@ ${AWS_FOLDER}
}

fix_perm() {
    chmod 600 -R ${AWS_FOLDER}
}

header_config

# test if region is mounted as secret
if test_config region
then
    echo "region found in ~/.aws mounted as secret"
# configure regions if variable specified at run time
elif [ "$REGION" != "" ] ; then
    header_config
    region_config $REGION
    fix_perm
# check if the region can be pulled from AWS IAM
elif test_iam
then
    echo "region detected from iam"
    REGION=$(wget -q -O- ${AWS_IAM} | grep 'region' |cut -d'"' -f4)
    header_config
    region_config $REGION
    fix_perm
else
  echo "No region detected"
  exit 1
fi

# test if key and secret are mounted as secret
if test_config aws_access_key_id
then
    echo "aws key and secret found in ~/.aws mounted as secrets"
# if both key and secret are declared
elif [ "$AWS_KEY" != "" ] && [ "$AWS_SECRET" != "" ]
then
    echo "aws_access_key_id = $AWS_KEY
aws_secret_access_key = $AWS_SECRET" >> ${AWS_FOLDER}/config
    fix_perm
# if the key and secret are not mounted as secrets
else
    echo "key and secret not available in ~/.aws/"
    if /usr/bin/aws ecr get-authorization-token | grep expiresAt
    then
        echo "iam role configured to allow ecr access"
    else
        echo "key and secret not mounted as secret, declared as variables or available from iam role"
        exit 1
    fi
fi

# update the auth token
# if [ "$REGISTRY_ID" = "" ]
# then 
#     aws_cli_exec=$(/usr/bin/aws ecr get-login-password)
# else
#     aws_cli_exec=$(/usr/bin/aws ecr get-login-password --registry-ids $REGISTRY_ID)
# fi
auth_token=$(aws ecr get-authorization-token --output text --no-cli-pager)

token=$(echo ${auth_token} | cut -d' ' -f 2)
reg_url=$(echo ${auth_token} | cut -d' ' -f 4)

echo "${token}" > /etc/nginx/aws_token.txt

sed -i "s|REGISTRY_URL|$reg_url|g" ${nx_conf}

sed -i "s|DBHOST|${DBHOST}|g;s|DBPORT|${DBPORT}|g;s|DBUSER|${DBUSER}|g;s|DBPASSWORD|${DBPASSWORD}|g;s|DBNAME|${DBNAME}|g" ${auth_conf}

/renew_token.sh &

exec "$@"
