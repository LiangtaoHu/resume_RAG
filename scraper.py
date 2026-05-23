from langchain_community.document_loaders import SeleniumURLLoader
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
from pydantic import BaseModel, Field
from typing import List

class JobListing(BaseModel):
    title: str = Field(description="Name of the job position of this specific job listing.")
    company: str = Field(description="The specific company this job listing was made by.")
    requirements: List[str] = Field(description="The specific minimum requirements for this job. Pay attention to the keywords/buzzwords present.")
    optional_skills: List[str] = Field(description="Skills that aren't needed and are optional but are good to have for this job.")

urls = ["https://www.indeed.com/?json=1&passedCtk=1jp0vn2h5j714800&vjk=021a4da4c8d14595&advn=4249684239653534"]
loader = SeleniumURLLoader(urls=urls, continue_on_failure=False, browser='Chrome', headless=True)
data = loader.load() # List of a single document

web_content = "\n\n".join([doc.page_content for doc in data])

llm = ChatOpenAI(model="gpt-4o")
structured_llm = llm.with_structured_output(JobListing, method="json_schema")

template = ChatPromptTemplate(
    [
        ("system", "You are an expert on getting people hired for CS Jobs. Your job is extracted the wanted information from a job listing."),
        ("user", "here is the job listing {content}")
    ]
)

chain = template | structured_llm
response = chain.invoke({"content": web_content})


