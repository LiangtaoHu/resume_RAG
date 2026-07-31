FROM public.ecr.aws/lambda/python:3.13

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY on_object_upload.py ${LAMBDA_TASK_ROOT}

CMD [ "on_object_upload.handler" ]