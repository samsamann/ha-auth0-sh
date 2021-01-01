#!/bin/sh

log_error() {
	echo "$1" >&2
}

delete_file() {
    rm -f $1
}

check_code() {
    if [ $1 -ne $2 ]; then
        log_error $3
        delete_file $4
        exit 1
    fi
}

parse_yaml() {
    pattern="^$1\:[[:space:]]*\(.*\)"
    sed -n "s/$pattern/\1/p" $2 2> /dev/null
}

if [ $# -eq 0 ]; then 
    log_error 'No parameters are passed.'
    exit 1
fi

if [ ! -r $1 ]; then
    log_error 'First parameter must be the secrets file.'
    exit 1
fi


DOMAIN=$(parse_yaml 'ha_auth0_domain' $1)
API_IDENTIFIER=$(parse_yaml 'ha_auth0_api_identifier' $1)
CLIENT_ID=$(parse_yaml 'ha_auth0_client_id' $1)
SCOPE='openid'
CLIENT_SECRET=$(parse_yaml 'ha_auth0_client_secret' $1)
TEMP=''

if [ -z $TEMP ]; then
    TEMP='/tmp'
fi

temp_file="${TEMP}/token$$.json"

responseCode=$(
    curl -s --request POST \
    --write-out "%{http_code}\n" \
    --output "$temp_file" \
    --url "https://$DOMAIN/oauth/token" \
    --header 'content-type: application/x-www-form-urlencoded' \
    --data "grant_type=password&username=$username&password=$password&audience=$API_IDENTIFIER&scope=$SCOPE&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET"
)

check_code $? 0 'Error: Check configuration or connection' $temp_file
check_code $responseCode 200 "Auth '$username'. Error: $(jq -r .error_description $temp_file)" $temp_file

echo "# User '$username' authenticated successfully."
accessToken=$(jq -r .access_token $temp_file)

responseCode=$(
    curl -s --request GET \
    --write-out "%{http_code}\n" \
    --output "$temp_file" \
    --url "https://$DOMAIN/userinfo" \
    --header "Authorization: Bearer $accessToken" \
    --header 'Accept: application/json'
)

check_code $? 0 'Error: Check configuration or connection' $temp_file

if [ $responseCode -eq 200 ]; then
    name=$(jq -r .name $temp_file)
    [ -z "$name" ] || echo "name=$name"
    delete_file $temp_file
fi

exit 0
