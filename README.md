# AWS IaC Igniter

From `root` to routine.

## Assumptions

You have a pristine AWS account that is owned exclusively by you.
This is not an AWS account that your enterprise provisioned for you.
You can sign in as the root user and no other users exist.

## Manual AWS Web Console steps

1. Go to your **Security credentials** settings and add an MFA device to the root user.

   Any account-local unique name is fine. We assume `mfa-root` for this document.

1. In the **IAM** console, create a new **User**.

   Any name is fine. We assume `igniter` for this document. This user **DOES NOT** have AWS Management Console access.

   **Attach policies directly**, and select the **AdministratorAccess** policy.

1. Add an MFA device to the `igniter` user.

   Any account-local unique name is fine. We assume `mfa-igniter` for this document.

1. Add an Access key to the `igniter` user.

   Use the **Download .csv file** button to grab the credentials. We assume the file is called `igniter_accessKeys.csv`.

   Add the missing `User Name` field to the first line of the `.csv` file, and add the user name on the second line in the same column.

   Import the credentials into a new AWS CLI v2 profile:

   ```shell
   aws configure import --csv file://igniter_accessKeys.csv
   ```

   Verify setup with `aws --profile igniter sts get-caller-identity`

1. Use [`aws-mfa-auth.sh`](https://github.com/toshitanaa/aws-cli-mfa-auth) to establish a temporary session.

   Verify setup with `aws --profile igniter-mfa sts get-caller-identity`

> [!WARNING]
> Don't skip switching over to the MFA session. We will break the authentication mechanism for static keys during further setup.

## IaC Backend Deployment

1. Deploy a new IaC state storage backend using [`iac-aws-bootstrap`](https://github.com/oliversalzburg/iac-aws-bootstrap):

   ```shell
   AWS_PROFILE=igniter-mfa AWS_REGION=eu-west-1 terraform apply
   ./display-backend.tf.sh > backend.tf
   ```

   Copy the `backend.tf` to the `terraform` folder in this workspace.

## Next steps

1. Deploy the configuration in the `terraform` folder.

   ```shell
   AWS_PROFILE=igniter-mfa AWS_REGION=eu-west-1 terraform init
   AWS_PROFILE=igniter-mfa AWS_REGION=eu-west-1 terraform apply
   ```
