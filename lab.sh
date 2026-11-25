#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
stack=cloudnotes-lab
export AWS_DEFAULT_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-south-1}}"
export AWS_PAGER=""
output() {
  aws cloudformation describe-stacks --stack-name "$stack" --output text \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue | [0]"
}
case "${1:-help}" in
  deploy)
    aws sts get-caller-identity --query Account --output text
    temp=$(mktemp)
    trap 'rm -f "$temp"' EXIT
    python3 - "$temp" <<'PY'
from pathlib import Path
from textwrap import indent
import sys
template = Path("stack.yaml").read_text()
source = indent(Path("analyze.py").read_text(), " " * 10)
Path(sys.argv[1]).write_text(template.replace("          # INSERT_ANALYZER", source))
PY
    aws cloudformation deploy --template-file "$temp" --stack-name "$stack" \
      --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset
    echo "On first deployment, allow about five minutes for S3 event delivery before the demo."
    ;;
  demo)
    file=${2:-sample.txt}
    python3 analyze.py "$file" >/dev/null
    bucket=$(output Bucket)
    table=$(output Table)
    key="notes/$(python3 -c 'import uuid; print(uuid.uuid4())').txt"
    aws s3 cp "$file" "s3://$bucket/$key"
    echo "Waiting for the summary in $table ..."
    for ((i=0;i<30;i++)); do
      row=$(aws dynamodb get-item --table-name "$table" --consistent-read \
        --key "{\"note\":{\"S\":\"$key\"}}" --query Item --output json)
      if [[ "$row" != "null" ]]; then
        python3 -c 'import json,sys; r=json.load(sys.stdin); print(json.dumps({k: int(v["N"]) if "N" in v else v["S"] for k,v in r.items()}, indent=2))' <<<"$row"
        exit 0
      fi
      sleep 2
    done
    echo "Result pending for $key. See Troubleshooting in README.md." >&2
    exit 1
    ;;
  logs) aws logs tail "$(output LogGroup)" --since 1h ;;
  cleanup)
    bucket=$(output Bucket)
    account=$(aws sts get-caller-identity --query Account --output text)
    echo "Deletes all notes in $bucket, results and stack $stack in account $account ($AWS_DEFAULT_REGION)."
    read -r -p 'Type DELETE to continue: ' confirmation
    [[ "$confirmation" == DELETE ]] || exit 1
    aws s3 rm "s3://$bucket" --recursive
    aws cloudformation delete-stack --stack-name "$stack"
    aws cloudformation wait stack-delete-complete --stack-name "$stack"
    echo "CloudNotes stack deleted."
    ;;
  *) echo "Usage: bash lab.sh deploy | demo [text-file] | logs | cleanup" ;;
esac
