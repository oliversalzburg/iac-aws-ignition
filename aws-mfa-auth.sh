#!/bin/bash

# MIT License
# 
# Copyright (c) 2024 Toshiyuki Tanaka
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -euo pipefail

# Function to prompt for input
prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local default_value="${3:-}"
    read -p "$prompt" input_value
    eval "$var_name='${input_value:-$default_value}'"
}

# Check for AWS CLI and jq
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required. Aborting."; exit 1; }

# Prompt for AWS profile name
prompt_input "Enter your AWS profile name (Default: default): " aws_profile "default"

# Fetch MFA devices
echo "Fetching MFA devices..."
mfa_devices=$(aws iam list-mfa-devices --profile "$aws_profile" --output json)

# Filter out U2F devices
mfa_devices=$(echo "$mfa_devices" | jq '.MFADevices | map(select(.SerialNumber | test("^arn:aws:iam::[0-9]+:mfa/")))')
mfa_count=$(echo "$mfa_devices" | jq 'length')

if [ "$mfa_count" -eq 0 ]; then
    echo "No compatible MFA devices found. Please set up a non-U2F MFA device for your IAM user."
    exit 1
elif [ "$mfa_count" -eq 1 ]; then
    mfa_arn=$(echo "$mfa_devices" | jq -r '.[0].SerialNumber')
    echo "Using MFA device: $mfa_arn"
else
    echo "Select an MFA device:"
    echo "$mfa_devices" | jq -r '.[].SerialNumber' | nl -w1 -s') '
    prompt_input "Enter the number of your MFA device: " device_number
    mfa_arn=$(echo "$mfa_devices" | jq -r ".[$(($device_number-1))].SerialNumber")
    echo "Using MFA device: $mfa_arn"
fi

# Input MFA code
prompt_input "Enter your MFA code: " token_code

# Get temporary credentials
echo "Fetching temporary credentials..."
creds=$(aws sts get-session-token --serial-number "$mfa_arn" --token-code "$token_code" --profile "$aws_profile" --output json)

# Create a new profile name
new_profile="${aws_profile}-mfa"
prompt_input "Enter a name for the new profile (Default: $new_profile): " new_profile "$new_profile"

# Set up the new profile
aws configure set aws_access_key_id "$(echo "$creds" | jq -r '.Credentials.AccessKeyId')" --profile "$new_profile"
aws configure set aws_secret_access_key "$(echo "$creds" | jq -r '.Credentials.SecretAccessKey')" --profile "$new_profile"
aws configure set aws_session_token "$(echo "$creds" | jq -r '.Credentials.SessionToken')" --profile "$new_profile"

# Get expiration time
expiration_local=$(date -d "$(echo "$creds" | jq -r '.Credentials.Expiration')" '+%Y-%m-%d %H:%M:%S %Z')

# Final message
echo
echo "Success! Temporary credentials have been set up."
echo "---------------------------------------------"
echo "Profile name: $new_profile"
echo "Expiration  : $expiration_local"
echo
echo "To use these credentials:"
echo "1. For specific commands: aws s3 ls --profile $new_profile"
echo "2. For this session: export AWS_PROFILE=$new_profile"
echo
echo "Remember to renew your credentials before they expire."
