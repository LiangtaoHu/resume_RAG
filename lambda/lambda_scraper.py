import json
import os
import boto3
from typing import List
from pydantic import BaseModel, Field
from langchain_community.document_loaders import SeleniumURLLoader
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI

from opensearchpy import AWSV4SignerAuth
from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_aws import BedrockEmbeddings
from langchain_opensearch import OpenSearchVectorSearch

secrets_client = boto3.client("secretsmanager")

def get_openai_key():
    secret_name = os.environ.get("SECRETS_MANAGER_NAME")
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        secret_dict = json.loads(response["SecretString"])
        return secret_dict["OPENAI_API_KEY"]
    except Exception as e:
        print(f"Error fetching secret from AWS: {e}")
        raise e

class JobListing(BaseModel):
    title: str = Field(description="Name of the job position of this specific job listing.")
    company: str = Field(description="The specific company this job listing was made by.")
    requirements: List[str] = Field(description="The specific minimum requirements for this job.")
    optional_skills: List[str] = Field(description="Skills that are optional but good to have.")

def lambda_handler(event, context):
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

        # Fetch OpenAI API key from Secrets Manager
        api_key = get_openai_key()

        # Initialize LLM with the injected API key
        llm = ChatOpenAI(model="gpt-4o", api_key=api_key)
        structured_llm = llm.with_structured_output(JobListing, method="json_schema")

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
        Position: {response.title}
        Requirements: {", ".join(response.requirements)}
        Optional Skills: {", ".join(response.optional_skills)}
        """

        doc = Document(
            page_content=job_text_content,
            metadata={
                "source_url": url,
                "company": response.company,
                "title": response.title
            }
        )

        # 2. Chunk the document
        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
        docs = text_splitter.split_documents([doc])

        bedrock_client = boto3.client("bedrock-runtime", region_name="us-east-1")
        
        embeddings = BedrockEmbeddings(
            client=bedrock_client,
            model_id="amazon.titan-embed-text-v2:0" 
        )

        session = boto3.Session()
        credentials = session.get_credentials()
        region = os.environ.get("AWS_REGION", "us-east-1")
        auth = AWSV4SignerAuth(credentials, region, "aoss") 

        vector_store = OpenSearchVectorSearch.from_documents(
            documents=docs,
            embedding=embeddings,
            opensearch_url=os.environ.get("OPENSEARCH_URL"),
            http_auth=auth,
            use_ssl=True,
            verify_certs=True,
            connection_class=OpenSearchVectorSearch.get_connection_class(),
            index_name="job-listings"
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