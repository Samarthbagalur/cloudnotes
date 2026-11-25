"""Count whitespace-separated words and logical lines in a small UTF-8 note."""
import json
import os
import sys
from pathlib import Path

LIMIT = 1024 * 1024


def summarize(data):
    if len(data) > LIMIT:
        raise ValueError("Choose a text file of at most 1 MiB.")
    text = data.decode("utf-8-sig")
    return {"words": len(text.split()), "lines": len(text.splitlines()), "bytes": len(data)}


def handler(event, context):
    import boto3

    detail = event["detail"]
    key = detail["object"]["key"]
    body = boto3.client("s3").get_object(Bucket=detail["bucket"]["name"], Key=key)["Body"]
    try:
        result = summarize(body.read(LIMIT + 1))
    finally:
        body.close()
    item = {"note": key, **result}
    boto3.resource("dynamodb").Table(os.environ["TABLE"]).put_item(Item=item)
    print(json.dumps(item))
    return item


if __name__ == "__main__":
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "sample.txt")
    try:
        with path.open("rb") as source:
            print(json.dumps(summarize(source.read(LIMIT + 1)), indent=2))
    except (ValueError, OSError) as exc:
        sys.exit(str(exc))
