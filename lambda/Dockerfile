# Use an AWS Lambda base image that includes Python 3.12 and Chromium
FROM public.ecr.aws/umi_h/aws-lambda-python-selenium:3.12

# Copy the requirements file and install python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy your actual Python code file into the Lambda task root
COPY lambda_scraper.py ${LAMBDA_TASK_ROOT}

# Tell AWS Lambda which python function to trigger on invocation
CMD [ "lambda_scraper.lambda_handler" ]