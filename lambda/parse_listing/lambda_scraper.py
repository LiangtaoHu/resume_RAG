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

# We'll have one collection for the database with one index. Index should have metadata describing the title, user, company
REGION_NAME = os.environ["REGION_NAME"]
OPENSEARCH_URL = os.environ.get("OPENSEARCH_URL")

class JobListing(BaseModel):
    position: str = Field(description="Name of the job position of this specific job listing.")
    company: str = Field(description="The specific company this job listing was made by.")
    requirements: List[str] = Field(description="The specific minimum requirements for this job.")
    optional_skills: List[str] = Field(description="Skills that are optional but good to have.")

dynamo_client = boto3.resource("dynamodb", region_name=REGION_NAME)
table = dynamo_client.Table("res-optimizer-user-data")

def lambda_handler(event, context):
    raw_headers = event.get("headers", {})
    headers = {k.lower(): v for k, v in raw_headers.items()}
    cookies = {}
    if "cookie" in headers:
        # Loop through all the cookies
        for cookie in headers["cookie"]:
            # We are mainly interested in the value as the key for each is just "cookie"
            # The value can be multi-cookie per actual cookie, with a separator of ";"
            cookie_string = cookie.get("value", "")
            for cookie_instance in cookie_string.split(";"):
                # We split again on the equals sign
                key, value = cookie_instance.split("=", 1)
                cookies[key.strip()] = value.strip()
    user_identity = cookies.get("idToken")
    if not user_identity:
        return {
            "statusCode": 401,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Unauthorized: Missing identity header from ALB"})
        }
    try:
        # Extract the URL from the Lambda event payload
        body = json.loads(event.get("body", "{}")) if "body" in event else event
        url = body.get("url")
        if not url:
            return {
                "statusCode": 400,
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

        # # Initialize LLM with the injected API key
        # llm = ChatOpenAI(model="gpt-4o", api_key=api_key)
        # structured_llm = llm.with_structured_output(JobListing, method="json_schema")
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
            Item = {
                'HK': user_identity,
                'SK': f"JOB-{response.company}-{response.position}",
                'company': response.company,
                'position': response.position,
                'url': url
            }
        )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": "Job parsed and successfully saved to AWS OpenSearch.",
                "data": response.model_dump()
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }