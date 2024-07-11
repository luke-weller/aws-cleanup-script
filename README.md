# AWS Cleanup Script

This repository contains a script for automated cleanup and deletion of all resources in an AWS account. The script terminates EC2 instances, deletes S3 buckets, RDS instances, IAM users and roles, VPCs, CloudWatch alarms, and budgets.

## Prerequisites

- **AWS CLI**: Make sure you have the AWS CLI installed. You can download and install it from [here](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).
- **AWS CLI Configuration**: Ensure your AWS CLI is configured with the necessary access keys. You can configure it using:

  ```sh
  aws configure
  ```

- **install JQ**: ensure jq is installed as its a dependency within the script to help remove non-empty s3 buckets

  ```
  brew install jq
  ```

## Installation

1. **Clone the repository**:

   ```sh
   git clone https://github.com/yourusername/aws-cleanup-script.git
   cd aws-cleanup-script
   ```

2. **Make the script executable**:
   ```sh
   chmod +x aws-cleanup.sh
   ```

## Usage

**WARNING**: Running this script will permanently delete all resources in your AWS account. Ensure you have backups of any important data before proceeding.

1. **Run the script**:

   ```sh˚
   ./aws-cleanup.sh
   ```

   or

   ```sh
   bash aws-cleanup.sh
   ```

## Script Overview

The script performs the following actions:

- Terminates all EC2 instances
- Deletes all EC2 volumes
- Empties and deletes all S3 buckets
- Deletes all RDS instances
- Deletes all IAM users and associated policies, access keys, and group memberships
- Deletes all IAM roles and associated policies
- Deletes all CloudFormation stacks
- Deletes all VPCs and associated subnets and internet gateways
- Deletes all CloudWatch alarms
- Deletes all Budgets

## Contributing

Contributions are welcome! Please open an issue or submit a pull request if you have any suggestions or improvements.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
