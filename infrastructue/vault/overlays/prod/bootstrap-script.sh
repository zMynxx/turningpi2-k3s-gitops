#/bin/bash
set -ex

# *************
# * Variables *
# *************
NUMKEYS=5
THRESHOLD=3
KEY_FILE='./unseal.json'
OUTPUT='/tmp/approle'
NAMESPACE='vault'

# *************
# * Functions *
# *************
# echo "Initializing Vault"
# kubectl --namespace $NAMESPACE exec --stdin=true --tty=true pod/vault-0 -- vault operator init -key-shares=$NUMKEYS -key-threshold=$THRESHOLD -format=json > $KEY_FILE
# read -p "Press Enter to continue after initializing Vault..."
#
# echo "Unsealing Vault-0" 
# for key in $(seq 0 $((THRESHOLD-1))); do
#     kubectl --namespace $NAMESPACE exec --stdin=true --tty=true pod/vault-0 -- vault operator unseal $(jq -r ".unseal_keys_b64[$key]" $KEY_FILE)
# done
# read -p "Press Enter to continue after unsealing Vault-0..."
#
# echo "Joining Vault nodes"
# for node in $(seq 1 2); do
#     kubectl --namespace $NAMESPACE exec --stdin=true --tty=true pod/vault-$node -- vault operator raft join http://vault-0.vault-internal:8200
# done
#
# read -p "Press Enter to continue after joining Vault nodes..."
#
# echo "Unsealing Vault"
# for node in $(seq 1 2); do
#   for key in $(seq 0 $((THRESHOLD-1))); do
#     kubectl --namespace $NAMESPACE exec --stdin=true --tty=true pod/vault-$node -- vault operator unseal $(jq -r ".unseal_keys_b64[$key]" $KEY_FILE)
#   done
# done
# read -p "Press Enter to continue after unsealing Vault..."

echo "Logging into Vault"
PASSWORD=$(jq -r '.root_token' $KEY_FILE) 
kubectl --namespace $NAMESPACE exec --stdin=true --tty=true pod/vault-0 -- /bin/sh -c "\
  vault login $PASSWORD; \
  vault secrets enable -version=2 -path=secret kv; \
  cat <<EOF | vault policy write readwrite -;
  path \"secret/data/*\" { capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"] }
  EOF
  cat <<EOF | vault policy write readonly -;
  path \"secret/data/*\" { capabilities = [\"read\", \"list\"] }
  EOF
  vault auth enable approle; \
  vault write auth/approle/role/external-secrets-operator token_policies=\"readonly\"; \
  vault read auth/approle/role/external-secrets-operator/role-id -format=yaml > $OUTPUT; \
  echo "---" >> $OUTPUT; \
  vault write -force auth/approle/role/external-secrets-operator/secret-id -format=yaml >> $OUTPUT;
"
read -p "Press Enter to continue fetching AppRole..."

echo "Fetching AppRole"
kubectl --namespace $NAMESPACE cp vault-0:/$OUTPUT $OUTPUT -c vault
echo "AppRole fetched - $OUTPUT"
read -p "Press Enter to continue creating Secret..."

echo "Update ClusterSecretStore"
yq -i ".spec.provider.vault.auth.appRole.roleId = $(yq 'select(documentindex==1) | .data.secret_id' $OUTPUT)" ./eso-clustersecretstore.yaml

echo "Creating Secret"
kubectl --namespace $NAMESPACE create secret generic vault-secret \
  --from-literal=secret-id=$(yq 'select(documentindex==1) | .data.secret_id' $OUTPUT)
echo "Secret created - vault-secret"

