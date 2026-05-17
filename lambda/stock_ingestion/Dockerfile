FROM public.ecr.aws/lambda/python:3.12

# Install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt --no-cache-dir

# Copy handler
COPY handler.py ${LAMBDA_TASK_ROOT}

CMD ["handler.lambda_handler"]
