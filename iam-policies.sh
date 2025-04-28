#!/bin/bash

for user in $(aws iam list-users --query 'Users[*].UserName' --output text); do
   echo "Fetching permissions for user: $user"
   aws iam list-attached-user-policies --user-name "$user" --output json > "$user-attached-policies.json"
   aws iam list-user-policies --user-name "$user" --output json > "$user-inline-policies.json"
   aws iam list-groups-for-user --user-name "$user" --output json > "$user-groups.json"
   for group in $(aws iam list-groups-for-user --user-name "$user" --query 'Groups[*].GroupName' --output text); do
       aws iam list-attached-group-policies --group-name "$group" --output json > "$group-attached-policies.json"
       aws iam list-group-policies --group-name "$group" --output json > "$group-inline-policies.json"
   done

   jq -n --arg user "$user" \
      --slurpfile attached "$user-attached-policies.json" \
      --slurpfile inline "$user-inline-policies.json" \
      --slurpfile groups "$user-groups.json" \
      '{user: $user, attached_policies: $attached[0], inline_policies: $inline[0], groups: $groups[0]}' > "$user-permissions-report.json"

   rm "$user-attached-policies.json" "$user-inline-policies.json" "$user-groups.json"
   if ls *-attached-policies.json 1> /dev/null 2>&1; then rm *-attached-policies.json; fi
   if ls *-inline-policies.json 1> /dev/null 2>&1; then rm *-inline-policies.json; fi
done

jq -s '.' *-permissions-report.json > iam-user-permissions.json 2>/dev/null || echo "[]" > iam-user-permissions.json
if ls *-permissions-report.json 1> /dev/null 2>&1; then rm *-permissions-report.json; fi