#/bin/bash
# set -ex

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
confirm_step() {
  read -p "Do you want to proceed with $1? (Yes/No): " response
  case $response in
  [yY] | [yY][eE][sS])
    return 0 # Proceed
    ;;
  *)
    return 1 # Skip
    ;;
  esac
}

echo "Initializing Vault..."
if confirm_step "initializing Vault"; then
  kubectl --namespace $NAMESPACE exec --stdin=true --tty=true pod/vault-0 -- vault operator init -key-shares=$NUMKEYS -key-threshold=$THRESHOLD -format=json >$KEY_FILE
  echo "Vault initialized successfully"
fi

echo "Unsealing Vault-0..."
if confirm_step "unsealing Vault-0"; then
  for key in $(seq 0 $((THRESHOLD - 1))); do
    kubectl --namespace $NAMESPACE exec --stdin=true --tty=true pod/vault-0 -- vault operator unseal $(jq -r ".unseal_keys_b64[$key]" $KEY_FILE)
  done
  echo "Vault-0 unsealed successfully"
fi

echo "Joining Vault nodes..."
if confirm_step "joining Vault nodes"; then
  for node in $(seq 1 2); do
    kubectl --namespace $NAMESPACE exec --stdin=true --tty=true pod/vault-$node -- vault operator raft join http://vault-0.vault-internal:8200
  done
  echo "Vault nodes joined successfully"
fi

echo "Unsealing Vault..."
if confirm_step "unsealing Vault"; then
  for node in $(seq 1 2); do
    for key in $(seq 0 $((THRESHOLD - 1))); do
      kubectl --namespace $NAMESPACE exec --stdin=true --tty=true pod/vault-$node -- vault operator unseal $(jq -r ".unseal_keys_b64[$key]" $KEY_FILE)
    done
  done
  echo "Vault unsealed successfully"
fi

echo "Logging into Vault, Generating ReadOnly & ReadWrite Policies, and the External-Secerts-Operator AppRole..."
if confirm_step "logging into Vault"; then
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
  echo "AppRole created successfully"
fi

echo "Fetching AppRole Credentials..."
if confirm_step "fetching AppRole"; then
  kubectl --namespace $NAMESPACE cp vault-0:/$OUTPUT $OUTPUT -c vault
  echo "AppRole fetched - $OUTPUT"
fi

echo "Creating Secret..."
if confirm_step "creating Secret"; then
  echo "Update ClusterSecretStore..."
  yq -i ".spec.provider.vault.auth.appRole.roleId = $(yq 'select(documentindex==1) | .data.secret_id' $OUTPUT)" ./eso-cluster-secret-store.yaml

  echo "Creating Secret..."
  kubectl --namespace $NAMESPACE create secret generic vault-secret \
    --from-literal=secret-id=$(yq 'select(documentindex==1) | .data.secret_id' $OUTPUT)

  echo "Secret created - vault-secret"
fi
