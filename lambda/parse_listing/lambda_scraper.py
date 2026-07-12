import json
import os
import boto3
from typing import List
from pydantic import BaseModel, Field
from langchain_community.document_loaders import SeleniumURLLoader
from langchain_core.prompts import ChatPromptTemplate

from opensearchpy import AWSV4SignerAuth
from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_aws import BedrockEmbeddings, ChatBedrockConverse
from langchain_opensearch import OpenSearchVectorSearch

# Identity now arrives via the HTTP API JWT authorizer claims
# (event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]).

REGION_NAME = os.environ["REGION_NAME"]
OPENSEARCH_URL = os.environ.get("OPENSEARCH_URL")


class JobListing(BaseModel):
    position: str = Field(description="Name of the job position of this specific job listing.")
    company: str = Field(description="The specific company this job listing was made by.")
    requirements: List[str] = Field(description="The specific minimum requirements for this job.")
    optional_skills: List[str] = Field(description="Skills that are optional but good to have.")


dynamo_client = boto3.resource("dynamodb", region_name=REGION_NAME)
table = dynamo_client.Table("res-optimizer-user-data")


def cors_headers(event):
    """Echo the caller's origin so the browser accepts the response. API Gateway's
    CORS configuration handles preflight OPTIONS, but does not inject these
    headers onto proxied Lambda responses, so every return below uses this."""
    origin = (event.get("headers", {}) or {}).get("origin", "*")
    return {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": origin,
    }


def get_user_identity(event):
    claims = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
    )
    return claims.get("sub")


def parse_body(event):
    """API Gateway HTTP API (payload_format_version 2.0) hands us a string body.
    Accept either a JSON object or a raw URL string (current frontend contract)."""
    raw = event.get("body")
    if not raw:
        return {}
    try:
        return json.loads(raw) if raw.startswith("{") else {"url": raw}
    except json.JSONDecodeError:
        return {"url": raw}


def lambda_handler(event, context):
    headers = cors_headers(event)
    user_identity = get_user_identity(event)
    if not user_identity:
        return {
            "statusCode": 401,
            "headers": headers,
            "body": json.dumps({"error": "Unauthorized: Missing identity from authorizer"})
        }

    try:
        body = parse_body(event)
        url = body.get("url")
        if not url:
            return {
                "statusCode": 400,
                "headers": headers,
                "body": json.dumps({"error": "Missing 'url' parameter in the request payload."})
            }

        # Load web content using Selenium with custom headless cloud arguments
        loader = SeleniumURLLoader(
            urls=[url],
            continue_on_failure=False,
            browser='chrome',
            headless=True,
            arguments=[
                "--headless=new",
                "--no-sandbox",
                "--disable-dev-shm-usage",
                "--disable-gpu",
                "--disable-extensions",
                "--single-process",
                "--user-data-dir=/tmp/user-data",
                "--data-path=/tmp/data-path",
                "--disk-cache-dir=/tmp/cache-dir",
            ]
        )
        data = loader.load()
        web_content = "\n\n".join([doc.page_content for doc in data])

        llm = ChatBedrockConverse(
            model_id="anthropic.claude-3-sonnet-20240229-v1:0",
            region_name="us-east-1"
        )
        structured_llm = llm.with_structured_output(JobListing)

        # Set up the chain and invoke
        template = ChatPromptTemplate([
            ("system", "You are an expert on getting people hired for CS Jobs. Your job is extracted the wanted information from a job listing."),
            ("user", "here is the job listing {content}")
        ])

        chain = template | structured_llm
        response = chain.invoke({"content": web_content})

        # Convert the structured Pydantic object back into a clean string for vectorization
        job_text_content = f"""
        Company: {response.company}
        Position: {response.position}
        Requirements: {", ".join(response.requirements)}
        Optional Skills: {", ".join(response.optional_skills)}
        """
        # Define metadata here
        doc = Document(
            page_content=job_text_content,
            metadata={
                "user-id": user_identity,
                "url": url,
                "company": response.company,
                "position": response.position,
                "title": f"{response.company}-{response.position}"
            }
        )

        # 2. Chunk the document
        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
        # Metadata is preserved upon chunking as well
        docs = text_splitter.split_documents([doc])

        bedrock_client = boto3.client("bedrock-runtime", region_name=REGION_NAME)

        embeddings = BedrockEmbeddings(
            client=bedrock_client,
            model_id="amazon.titan-embed-text-v2:0"
        )

        session = boto3.Session()
        credentials = session.get_credentials()
        auth = AWSV4SignerAuth(credentials, REGION_NAME, "aoss")

        vector_store = OpenSearchVectorSearch.from_documents(
            documents=docs,
            embedding=embeddings,
            opensearch_url=OPENSEARCH_URL,
            http_auth=auth,
            use_ssl=True,
            verify_certs=True,
            connection_class=OpenSearchVectorSearch.get_connection_class(),
            index_name=f"{user_identity.lower()}-job-listings"
        )

        # Save to DynamoDB
        table.put_item(
            Item={
                'HK': "USER#" + user_identity,
                'SK': f"JOB#{response.company}-{response.position}",
                'company': response.company,
                'position': response.position,
                'url': url
            }
        )

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({
                "message": "Job parsed and successfully saved to AWS OpenSearch.",
                "data": response.model_dump()
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": str(e)})
        }
