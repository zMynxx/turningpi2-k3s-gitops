#!/usr/bin/env sh
# Credit: https://picluster.ricsanfre.com/docs/vault/#vault-automatic-unseal

#Define a timestamp function
timestamp() {
date "+%b %d %Y %T %Z"
}


URL=https://localhost:8200
KEYS_FILE=/etc/vault/unseal.json

LOG=info

SKIP_TLS_VERIFY=true

if [ true = "$SKIP_TLS_VERIFY" ]
then
  CURL_PARAMS="-sk"
else
  CURL_PARAMS="-s"
fi

# Add timestamp
echo "$(timestamp): Vault-useal started" | tee -a $LOG
echo "-------------------------------------------------------------------------------" | tee -a $LOG

initialized=$(curl $CURL_PARAMS $URL/v1/sys/health | jq '.initialized')

if [ true = "$initialized" ]
then
  echo "$(timestamp): Vault already initialized" | tee -a $LOG
  while true
  do
    status=$(curl $CURL_PARAMS $URL/v1/sys/health | jq '.sealed')
    if [ true = "$status" ]
    then
        echo "$(timestamp): Vault Sealed. Trying to unseal" | tee -a $LOG
        # Get keys from json file
        for i in `jq -r '.keys[]' $KEYS_FILE` 
          do curl $CURL_PARAMS --request PUT --data "{\"key\": \"$i\"}" $URL/v1/sys/unseal
        done
    sleep 10
    else
        echo "$(timestamp): Vault unsealed" | tee -a $LOG
        break
    fi
  done
else
  echo "$(timestamp): Vault not initialized yet"
fi
