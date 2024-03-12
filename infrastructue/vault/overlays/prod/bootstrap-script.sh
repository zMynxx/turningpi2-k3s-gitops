#/bin/sh

KEY_FILE=./unseal.json
echo "Initializing Vault"
kubectl exec --stdin=true --tty=true pod/vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > ./unseal.json

echo "Unsealing Vault-0" 
kubectl exec --stdin=true --tty=true pod/vault-0 -- vault operator unseal $(jq -r '.unseal_keys_b64[0]' $KEY_FILE) 

echo "Joining Vault nodes"
kubectl exec --stdin=true --tty=true pod/vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
kubectl exec --stdin=true --tty=true pod/vault-2 -- vault operator raft join http://vault-0.vault-internal:8200

echo "Unsealing Vault"
kubectl exec --stdin=true --tty=true pod/vault-1 -- vault operator unseal $(jq -r '.unseal_keys_b64[0]' $KEY_FILE) 
kubectl exec --stdin=true --tty=true pod/vault-2 -- vault operator unseal $(jq -r '.unseal_keys_b64[0]' $KEY_FILE)

echo "Logging into Vault"
kubectl exec --stdin=true --tty=true pod/vault-0 -- vault login $(jq -r '.root_token' $KEY_FILE)

echo "Enabling Vault secrets - KV v2"
vault secrets enable -version=2 -path=secret kv

POLICY_DIR=$(pwd)
echo "Creating Vault policies"
vault policy write readwrite /etc/vault/policy/read-write-secrets.hcl
vault policy write readonly /etc/vault/policy/read-only-secrets.hcl

echo "Creating Vault roles"
vault auth enable approle
vault write auth/approle/role/external-secrets-operator token_policies="readonly"
vault read auth/approle/role/external-secrets-operator/role-id 
vault write -force auth/approle/role/external-secrets-operator/secret-id

