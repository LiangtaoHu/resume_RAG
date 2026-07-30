FROM public.ecr.aws/lambda/python:3.13

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY s3_presigned_url.py ${LAMBDA_TASK_ROOT}

CMD [ "s3_presigned_url.handler" ]