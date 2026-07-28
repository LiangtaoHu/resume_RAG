FROM umihico/aws-lambda-selenium-python:latest

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY lambda_scraper.py ${LAMBDA_TASK_ROOT}

CMD [ "lambda_scraper.lambda_handler" ]