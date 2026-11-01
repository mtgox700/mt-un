FROM python:3.13-slim
RUN python -m pip install --no-cache-dir cryptography==50.0.2
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1
CMD ["python", "-B", "scripts/local_quality.py"]
