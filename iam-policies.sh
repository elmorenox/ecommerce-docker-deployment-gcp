#!/bin/bash

# Create output directory
mkdir -p gcp-iam-reports

# Get all IAM policy bindings at the project level
PROJECT_ID=$(gcloud config get-value project)
echo "Fetching IAM permissions for project: $PROJECT_ID"

# Get project-level IAM bindings
gcloud projects get-iam-policy $PROJECT_ID --format=json > gcp-iam-reports/project-iam-policy.json

# Initialize an empty array for the final report
echo "[]" > gcp-iam-reports/gcp-user-permissions.json

# Process each user with IAM bindings
for email in $(jq -r '.bindings[].members[]' gcp-iam-reports/project-iam-policy.json | grep "user:" | sed 's/user://g' | sort -u); do
  echo "Processing permissions for user: $email"
  
  # Create a temporary file for this user's roles
  echo "{\"user\": \"$email\", \"roles\": []}" > gcp-iam-reports/temp-user.json
  
  # Find all roles bound to this user at the project level
  for role in $(jq -r ".bindings[] | select(.members[] | contains(\"user:$email\")) | .role" gcp-iam-reports/project-iam-policy.json); do
    # Add role to the user's roles array
    jq --arg role "$role" '.roles += [$role]' gcp-iam-reports/temp-user.json > gcp-iam-reports/temp-user-new.json
    mv gcp-iam-reports/temp-user-new.json gcp-iam-reports/temp-user.json
  done
  
  # Get service account keys if applicable (only for service accounts)
  if [[ $email == *".gserviceaccount.com" ]]; then
    echo "Checking for service account keys for: $email"
    gcloud iam service-accounts keys list --iam-account=$email --format=json > gcp-iam-reports/temp-sa-keys.json
    jq --slurpfile keys gcp-iam-reports/temp-sa-keys.json '. + {service_account_keys: $keys[0]}' gcp-iam-reports/temp-user.json > gcp-iam-reports/temp-user-new.json
    mv gcp-iam-reports/temp-user-new.json gcp-iam-reports/temp-user.json
    rm gcp-iam-reports/temp-sa-keys.json
  fi
  
  # Append this user to the final report
  jq -s '.[0] + [.[1]]' gcp-iam-reports/gcp-user-permissions.json gcp-iam-reports/temp-user.json > gcp-iam-reports/temp-combined.json
  mv gcp-iam-reports/temp-combined.json gcp-iam-reports/gcp-user-permissions.json
  
  # Remove temporary user file
  rm gcp-iam-reports/temp-user.json
done

# Check for service accounts and add them to the report
echo "Fetching service accounts"
gcloud iam service-accounts list --format=json > gcp-iam-reports/service-accounts.json

for sa_email in $(jq -r '.[].email' gcp-iam-reports/service-accounts.json); do
  # Skip if already processed above
  if grep -q "\"user\": \"$sa_email\"" gcp-iam-reports/gcp-user-permissions.json; then
    continue
  fi
  
  echo "Processing permissions for service account: $sa_email"
  
  # Create a temporary file for this service account
  echo "{\"user\": \"$sa_email\", \"roles\": [], \"type\": \"service_account\"}" > gcp-iam-reports/temp-sa.json
  
  # Find all roles bound to this service account at the project level
  for role in $(jq -r ".bindings[] | select(.members[] | contains(\"serviceAccount:$sa_email\")) | .role" gcp-iam-reports/project-iam-policy.json); do
    # Add role to the service account's roles array
    jq --arg role "$role" '.roles += [$role]' gcp-iam-reports/temp-sa.json > gcp-iam-reports/temp-sa-new.json
    mv gcp-iam-reports/temp-sa-new.json gcp-iam-reports/temp-sa.json
  done
  
  # Get service account keys
  gcloud iam service-accounts keys list --iam-account=$sa_email --format=json > gcp-iam-reports/temp-sa-keys.json
  jq --slurpfile keys gcp-iam-reports/temp-sa-keys.json '. + {service_account_keys: $keys[0]}' gcp-iam-reports/temp-sa.json > gcp-iam-reports/temp-sa-new.json
  mv gcp-iam-reports/temp-sa-new.json gcp-iam-reports/temp-sa.json
  rm gcp-iam-reports/temp-sa-keys.json
  
  # Append this service account to the final report
  jq -s '.[0] + [.[1]]' gcp-iam-reports/gcp-user-permissions.json gcp-iam-reports/temp-sa.json > gcp-iam-reports/temp-combined.json
  mv gcp-iam-reports/temp-combined.json gcp-iam-reports/gcp-user-permissions.json
  
  # Remove temporary service account file
  rm gcp-iam-reports/temp-sa.json
done

echo "IAM permissions report completed. Results in gcp-iam-reports/gcp-user-permissions.json"