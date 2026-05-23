import json
import os
import boto3
from typing import List
from pydantic import BaseModel, Field
from langchain_community.document_loaders import SeleniumURLLoader
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI

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

# Define Pydantic schema outside the handler for efficiency
class JobListing(BaseModel):
    title: str = Field(description="Name of the job position of this specific job listing.")
    company: str = Field(description="The specific company this job listing was made by.")
    requirements: List[str] = Field(description="The specific minimum requirements for this job.")
    optional_skills: List[str] = Field(description="Skills that are optional but good to have.")

def lambda_handler(event, context):
    try:
        # Extract the URL dynamically from the Lambda event payload
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

        # Return structured response
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(response.model_dump())
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }