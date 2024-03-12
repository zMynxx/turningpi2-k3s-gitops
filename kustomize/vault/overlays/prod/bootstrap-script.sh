#/bin/sh

echo "Initializing Vault"
kubectl exec --stdin=true --tty=true pod/vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > /etc/vault/unseal.json


echo "Joining Vault nodes"
kubectl exec --stdin=true --tty=true pod/vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
kubectl exec --stdin=true --tty=true pod/vault-2 -- vault operator raft join http://vault-0.vault-internal:8200

echo "Unsealing Vault"
kubectl exec --stdin=true --tty=true pod/vault-1 -- vault operator unseal $(jq -r '.unseal_keys_b64[0]' /etc/vault/unseal.json) 
kubectl exec --stdin=true --tty=true pod/vault-2 -- vault operator unseal $(jq -r '.unseal_keys_b64[0]' /etc/vault/unseal.json)

echo "Logging into Vault"
kubectl exec --stdin=true --tty=true pod/vault-0 -- vault login $(jq -r '.root_token' /etc/vault/unseal.json)

echo "Enabling Vault secrets - KV v2"
vault secrets enable -version=2 -path=secret kv

echo "Creating Vault policies"
vault policy write readwrite /etc/vault/policy/read-write-secrets.hcl
vault policy write readonly /etc/vault/policy/read-only-secrets.hcl

echo "Creating Vault roles"
vault auth enable approle
vault write auth/approle/role/external-secrets-operator token_policies="readonly"
vault read auth/approle/role/argocd/role-id 
vault write -force auth/approle/role/argocd/secret-id

