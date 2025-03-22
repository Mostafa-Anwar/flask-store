
FROM python:3.9-slim

COPY run.py requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ app/

ENV PYTHONPATH=/app FLASK_RUN_HOST=0.0.0.0
WORKDIR /app

EXPOSE 5000

CMD ["python", "../run.py"]
