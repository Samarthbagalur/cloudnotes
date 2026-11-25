# CloudNotes • AWS on Ubuntu

Upload a study note and watch AWS count its words and lines. The original file stays in private object storage. A separate database row holds its summary. This project runs from the terminal. It needs no website, CloudFront distribution, Docker installation or public server.

## 1. Try the calculation on Ubuntu

Download the ZIP into Downloads and open Terminal.

```bash
cd ~/Downloads
unzip cloudnotes-ubuntu.zip
cd cloudnotes
python3 analyze.py sample.txt
```

If Ubuntu reports a missing command, install the basic tools with `sudo apt update && sudo apt install python3 unzip`. The included sample produces **7 words, 2 lines and 57 bytes**. The local command tests the same Python calculation Lambda will run. It does not contact AWS. Try changing one word in the file and running it again.

## 2. Set up access for the AWS demo

Use an AWS account or student lab that lets you create the resources in the table below, create and pass the Lambda execution role, use CloudFormation, upload files, and read the results and logs. Some college accounts restrict IAM role creation. Ask the lab administrator for an approved role or environment if deployment reports AccessDenied.

1. Check `aws --version`. Use AWS CLI v2. If missing, run `uname -m` and follow the Linux installation steps for x86_64 or aarch64 in the [official AWS CLI guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
2. Use the CLI credentials supplied by your lab. For an IAM Identity Center account, run `aws configure sso --profile student`, then `aws sso login --profile student` and `export AWS_PROFILE=student`. Your administrator supplies the start URL and SSO region. For lab-issued temporary credentials, follow your lab's CLI setup, including its session token.
3. Run `aws sts get-caller-identity` and check that the account shown is the one you want to use. Keep credentials outside the project.
4. The script defaults to Mumbai (ap-south-1) unless your shell already specifies a region. To explicitly select Mumbai, run `export AWS_REGION=ap-south-1`. Use the same account and region throughout.

## 3. Deploy and demonstrate

From the extracted cloudnotes directory run:

```bash
bash lab.sh deploy
```

Wait for deployment to finish. On the first deployment, allow about five more minutes for S3 to start delivering events to EventBridge. Then run:

```bash
bash lab.sh demo
bash lab.sh logs
```

The demo validates the sample, uploads it and polls DynamoDB for its result. Each upload gets a unique note ID. The printed AWS result contains that ID and the three counts. A repeated delivery of the same upload writes to the same row. To try your own note, run `bash lab.sh demo "$HOME/Downloads/my-note.txt"`. Use a UTF-8 text file up to 1 MiB. Words are separated by whitespace and a final newline does not add an extra line.

**Where to look in the AWS Console:** Select the deployment region. Open CloudFormation → Stacks → cloudnotes-lab → Outputs. Use Bucket to locate the original file in S3 under notes/, Table to find the row under DynamoDB → Explore items, and LogGroup to locate the processing record in CloudWatch Logs.

## 4. Explain it in a presentation

| AWS topic | Service | What you can show |
|---|---|---|
| Object storage | S3 | Open the private bucket and show the uploaded .txt file. |
| Event-driven architecture | EventBridge | Open the rule under the stack's Resources tab. It matches new objects in this bucket under notes/. |
| Serverless compute | Lambda | Open the function and show how the handler reads the object and calls summarize(). |
| NoSQL databases | DynamoDB | Find the note ID in the table and compare its counts with the local output. |
| Access control | IAM | Show the function's role. It can read notes, write summaries and publish logs. |
| Monitoring | CloudWatch | Show a log entry for the same note ID. Inspect the Lambda Invocations and Errors metrics. |
| Infrastructure as code | CloudFormation | Show the stack and how one template describes the resources. |
| Regions and account identity | AWS CLI and STS | Show the account used by the CLI and select the same region in the console. |

**Two-minute demonstration:** Start by opening sample.txt and predicting the word count. Run the local command. Next run the cloud demo and point out the matching result. Show the original in S3 and its summary in DynamoDB, using the note ID to connect them. Finish by explaining that uploading the file triggers processing automatically, even when nobody is polling for the result.

## 5. Connect this project to the wider AWS syllabus

The running lab focuses on core services. Use these discussion questions for additional foundational topics without deploying extra infrastructure.

| Topic | Presentation question and answer |
|---|---|
| Networking and VPC | Where is the server's IP address? The client uses regional AWS service endpoints over HTTPS. The demo needs no customer-managed subnet, NAT gateway or inbound security group rule. |
| EC2, EBS and scaling | How would an instance-based version work? An EC2 worker would need an OS, EBS storage and a way to receive jobs. Auto Scaling could adjust the number of workers. |
| RDS and SQL | When would a relational database help? If notes had owners, courses and enrolments with joins, RDS could support that relational model. |
| SQS and SNS | How could we handle a backlog or notify students? Put SQS between the rule and worker for a visible queue, or publish completion notifications through SNS. |
| Route 53, CloudFront and web delivery | What would a public website add? Route 53 can provide DNS for a custom domain and CloudFront can cache a frontend. The terminal demo needs neither. |
| Security and auditing | How would you investigate a change? CloudWatch shows function activity. CloudTrail records supported AWS API activity, with S3 object-level auditing requiring data event configuration. |
| Reliability and recovery | How could you recover notes or results? Consider S3 versioning and DynamoDB point-in-time recovery. Both require deliberate configuration and retention choices. |
| Cost management | What drives usage? Stored bytes, uploads, event processing, function execution, database operations and logs. Actual charges depend on usage, region and account credits. Review Billing and Cost Management before and after the lab. |

## 6. Remove the AWS resources

```bash
bash lab.sh cleanup
```

Check the bucket, account and region printed by the script. Type DELETE when ready. This empties the project's bucket and deletes the stack, including database rows and logs. Save any evidence you want for your presentation first. The local project folder stays on Ubuntu.

## Troubleshooting

- **Unable to locate credentials / expired token** — Refresh the lab credentials or run your SSO login again. Verify with aws sts get-caller-identity.
- **Stack creation fails** — Open the stack's Events tab and read the first resource marked CREATE_FAILED. A new stack that ends in ROLLBACK_COMPLETE must be removed before deploying it again. Check that it is the failed cloudnotes-lab stack in the intended account.
- **No result after the polling window** — Check the stack's actual bucket and region, wait for initial EventBridge activation and run the demo again to generate a fresh upload. Run bash lab.sh logs. Inspect EventBridge rule metrics and Lambda Errors if the issue persists.
- **Stack not found** — Use the same profile and region as the deploy command.
- **Unexpected count** — Punctuation attached to a word counts with the word. UTF-8 characters can occupy multiple bytes. The bytes field includes line endings.

## Files

- analyze.py contains the calculation, local entry point and Lambda handler.
- stack.yaml describes the infrastructure. The deploy script inserts the Python source into the marked line before submitting the template.
- lab.sh deploys the stack, runs the demo, shows logs and removes the lab.
- sample.txt is the two-line demonstration note.

[AWS documentation on activating S3 events](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-event-notifications-eventbridge.html) · [S3 event structure](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ev-events.html) · [AWS Lambda Python runtimes](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html)
